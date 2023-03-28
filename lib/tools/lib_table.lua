local error_wrapper = require('lib.tools.error_wrapper')

local lib_table = {
    __name = 'lib_table'
}

function lib_table:len(t)
    if (type(t) == 'table') then
        local len = 0

        for k in pairs(t) do
            len = len + 1
        end
        
        return len
    end

    return 0
end

function lib_table:map_hash(t)
    if (type(t) ~= 'table') then
        return {}
    end

    local h_types = {
        ['number'] = true,
        ['boolean'] = true,
        ['string'] = true
    }

    local map = {}

    for k, v in pairs(t) do
        if (not h_types[type(v)]) then
            goto continue
        end

        if (type(v) == 'boolean') then
            v = tostring(v)
        end

        if map[v] then
            if h_types[type(map[v])] then
                map[v] = {map[v]}
            end

            table.insert(map[v], k)
        else
            map[v] = k
        end

        ::continue::
    end

    return map
end

--This function may be needed for convert list object to hash table with dotted keys.
--Dotted keys shows the list keys structure
--
--Example:
--
-- list = {
--     a = {
--         b = 'btest',
--         c = 'ctest',
--     },
--     d = 'dtest',
--     e = {
--         e1 = 'e1test',
--         f = {
--             f1 = 'f1test',
--             f2 = {
--                 g = 'gtest',
--                 h = 'htest',
--                 i = {
--                     i1 = 'i1test',
--                     i2 = 'i2test'
--                 }
--             }
--         }
--     }
-- }
--
-- simple_hash = lib_table:dot_list(list)
--
--Output:
--
-- e.f.f1 ==> f1test
-- a.c ==> ctest
-- e.e1 ==> e1test
-- e.f.f2.i.i1 ==> i1test
-- e.f.f2.i.i2 ==> i2test
-- e.f.f2.h ==> htest
-- d ==> dtest
-- e.f.f2.g ==> gtest
-- a.b ==> btest


function lib_table:dot_list(list, parent)
    local parent = parent or ''
    local tmp_list1 = {}

    for p_name, c_name in pairs(list) do

        if (type(c_name) == 'table') then
            local tmp_list2 = {}

            if(#parent > 0) then
                tmp_list2 = self:dot_list(c_name, parent .. '.' .. p_name)
            else
                tmp_list2 = self:dot_list(c_name, p_name)
            end

            for p_name2, c_name2 in pairs(tmp_list2) do
                tmp_list1[p_name2] = c_name2
            end

            tmp_list2 = nil
        end

        if (type(c_name) == 'string') then
            if(#parent > 0) then
                tmp_list1[parent .. '.' .. p_name] = c_name
            else
                tmp_list1[p_name] = c_name
            end
        end
    end

    return tmp_list1
end

function lib_table:compare_by_template(template, original, errors)
    for parameter, value in pairs(template) do
        if (not original[parameter]) then
            error_wrapper:add(errors, parameter, 'not defined')

            goto continue
        end

        if (type(original[parameter]) ~= type(value)) then
            -- print(parameter)
            -- print(type(original[parameter]), type(value))
            error_wrapper:add(errors, parameter, 'type error')
        end

        ::continue::
    end
end

return lib_table