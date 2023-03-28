local lbcp = require('lbcp2')
local json = require('cjson')
local base64 = require('lib.base64')
local error_wrapper = require('lib.tools.error_wrapper')

local directive = {
    __name = 'directive'
}

function directive:parse(bc)
    local bc_json, bc_json_err = lbcp.parse(bc)
 
    if (not bc_json) then
        return false, error_wrapper:new(self, bc_json_err)
    end

    local json_ok, bc_t = pcall(json.decode, bc_json)

    if (not json_ok) then
        return false, error_wrapper:new(self, 'JSON error:' .. tostring(bc_t))
    end

    for i = 1, #bc_t do
        for j = 1, #bc_t[i]['constants'] do
            if (bc_t[i]['constants'][j][2] ~= 'S') then
                goto continue
            end

            local b64_str = bc_t[i]['constants'][j][3]
            bc_t[i]['constants'][j][3] = base64.decode(b64_str)

            ::continue::
        end
    end

    return bc_t
end

function directive:chk_entry_point(instructions, counters, idx)
    local l, a, b, c, d, e = table.unpack(instructions[idx])

    if (a == counters.directive_link and b == 'NEWTABLE') then
        counters.table_meta = {
            [1] = {
                ['c'] = c,
                ['f'] = d + e
            }
        }

        return idx + 1 --returns jump to next instruction
    end

    return false
end

function directive:get_constant(constants, idx)
    local idx = idx + 1
    local row = constants[idx]

    if (row[2] == 'N') then
        return nil
    elseif (row[2] == 'B') then
        return row[3] == 'true'
    elseif (row[2] == 'F') then
        return tonumber(row[3])
    elseif (row[2] == 'I') then
        return math.tointeger(row[3])
    elseif (row[2] == 'S') then
        return tostring(row[3])
    end
end

function directive:get_table(instructions, constants, counters, idx)
    local alias = '*alias*' .. tostring(idx)
    local jmp = 0
    local targ = {}
    local map = {
        [1] = {
            [1] = targ, --current
            [2] = targ --prev
        },
    }

    for i=idx, #instructions do
        local l, a, b, c, d, e = table.unpack(instructions[i])
        local key = ''

        if (b == 'NEWTABLE') then
            local prev_a = instructions[i - 1][2]
            table.insert(counters.table_meta, {
                ['c'] = c,
                ['f'] = d + e
            })

            if (a == prev_a) then
                counters.table_meta[#counters.table_meta]['g'] = true
            end

            map[#map][1][alias] = {}
            map[#map + 1] = {
                [1] = map[#map][1][alias], --оставляем ссылку на текущую таблицу
                [2] = map[#map][1] --оставляем ссылку на предыдущую таблицу
            }

            goto continue
        end

        if (b == 'LOADK') then
            table.insert(map[#map][1], self:get_constant(constants, d))

            counters.table_meta[#counters.table_meta]['f'] = counters.table_meta[#counters.table_meta]['f'] - 1

            if (counters.table_meta[#counters.table_meta]['g'] and counters.table_meta[#counters.table_meta]['f'] == 0) then
                key = #map[#map][2] + 1

                goto close_table
            end

            goto continue
        end

        if (b == 'SETFIELD') then -- в Lua 5.2 SETTABLE
            if (e > c and e == counters.table_meta[#counters.table_meta]['c']) then
                key = self:get_constant(constants, d)

                goto close_table
            end

            local k = self:get_constant(constants, d)
            local v = self:get_constant(constants, e)
            map[#map][1][k] = v

            counters.table_meta[#counters.table_meta]['f'] = counters.table_meta[#counters.table_meta]['f'] - 1

            if (counters.table_meta[#counters.table_meta]['g'] and counters.table_meta[#counters.table_meta]['f'] == 0) then
                key = #map[#map][2] + 1

                goto close_table
            end

            goto continue
        end

        if (b == 'SETLIST') then
            if (counters.table_meta[#counters.table_meta]['g'] and counters.table_meta[#counters.table_meta]['f'] == 0) then
                key = #map[#map][2] + 1
    
                goto close_table
            end
        end

        if (b == 'CALL' and a == counters.directive_link) then --final
            jmp = i + 1
            break
        end

        goto continue

        ::close_table::
        map[#map][2][alias] = nil
        map[#map][2][key] = json.decode(json.encode(map[#map][1]))
        table.remove(map[#map], 1)
        table.remove(map, #map)

        counters.table_meta[#counters.table_meta - 1]['f'] = (counters.table_meta[#counters.table_meta - 1]['f']) - 1

        if (#counters.table_meta > 1) then
            table.remove(counters.table_meta, #counters.table_meta)
        end

        ::continue::
    end

    return targ, jmp
end

function directive:get_targs(directive_name, src)
    if (not directive_name) then
        return false, error_wrapper:new(self, 'directive_name not defined!')
    end

    if (not src) then
        return false, error_wrapper:new(self, 'src not defined!')
    end

    local bc_t, bc_t_err = self:parse(src)

    if (not bc_t) then
        return false, error_wrapper:chain(self, bc_t_err)
    end

    local targs = {}
    local counters = {}

    for i=1, #bc_t do
        local chunk = bc_t[i]

        for j=1, #chunk.instructions do
            local l, a, b, c, d, e = table.unpack(chunk.instructions[j])
            
            if (b == 'GETTABUP' and directive_name == self:get_constant(chunk.constants, e)) then
                counters.directive_link = a
                local idx = self:chk_entry_point(chunk.instructions, counters, j + 1)
    
                if (not idx) then
                    goto continue
                end
    
                local targ, jmp = self:get_table(chunk.instructions, chunk.constants, counters, idx)
    
                if targ then
                    table.insert(targs, targ)
                    j = jmp
                end
            end
    
            ::continue::
        end
    end

    return targs
end

return directive