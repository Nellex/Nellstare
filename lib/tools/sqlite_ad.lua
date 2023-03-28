local error_wrapper = require('lib.tools.error_wrapper')
local lib_file = require('lib.tools.lib_file')
local fs = require('lfs')
local sha = require('lib.sha2')
local sqlite = require('lsqlite3complete')
local lib_string = require('lib.tools.lib_string')

local sqlite_ad = {
    __name = 'sqlite_ad'
}

function sqlite_ad:attach(db, db_list)
    if (type(db_list) ~= 'table') then
        -- return false, {['parameter'] = 'db_list', ['error'] = 'db_list must be a table!'}
        return false, error_wrapper:new(self, 'db_list must be a table!')
    end

    local errors = {}

    for k, v in pairs(db_list) do
        if (not lib_file:is_exist(v)) then
            -- table.insert(errors, {['parameter'] = v, ['error'] = 'not exist'})
            error_wrapper:add(errors, v, 'not exist')

            goto continue
        end

        if (fs.attributes(v, 'size') == 0) then
            -- table.insert(errors, {['parameter'] = v, ['error'] = 'empty file'})
            error_wrapper:add(errors, v, 'empty file')

            goto continue
        end

        local res = db:exec('ATTACH DATABASE \'' .. v .. '\' AS ' .. k .. ';')

        if (res == sqlite.NOTADB) then
            -- table.insert(errors, {['parameter'] = v, ['error'] = 'not a sqlite database'})
            error_wrapper:add(errors, v, 'not a sqlite database')
        elseif (res == sqlite.CANTOPEN) then
            -- table.insert(errors, {['parameter'] = v, ['error'] = 'error while opening database'})
            error_wrapper:add(errors, v, 'error while opening database')
        elseif (res ~= sqlite.OK) then
            -- table.insert(errors, {['parameter'] = v, ['error'] = 'query error. error code:' .. tostring(res)})
            error_wrapper:add(errors, v, 'query error. error code:' .. tostring(res))
        end

        ::continue::
    end

    if (#errors > 0) then
        -- return false, errors
        return false, error_wrapper:new(self, errors)
    end

    return true
end

function sqlite_ad:detach(db, schema)
    local res = db:exec('DETACH DATABASE \'' .. schema .. '\';')

    if (res == sqlite.OK) then
        return true
    end

    -- return false, res
    return false, error_wrapper:new(self, res)
end

function sqlite_ad:detach_all(db)
    local stmt = db:prepare('PRAGMA database_list;')

    if (not stmt) then
        -- return false, 'statement error!'
        return false, error_wrapper:new(self, 'statement error!')
    end

    local db_list, db_list_err = self:get_rows(stmt, true)

    if (not db_list) then
        -- return false, db_list_err
        return false, error_wrapper:chain(self, db_list_err)
    end

    local errors = {}

    for i = 1, #db_list do
        --использование PRAGMA в запросах не дает возможности отфильтровать
        --данные, да и в принципе условие на итерации будет дешевле, чем готовить
        --отфильтрованный список по вложенным базам
        if (db_list[i][2] == 'main') then
            goto continue
        end

        local res = db:exec('DETACH DATABASE \'' .. db_list[i][2] .. '\';')

        if (res ~= sqlite.OK) then
            -- table.insert(errors, {['parameter'] = db_list[i][2], ['error'] = tostring(res)})
            error_wrapper:add(errors, db_list[i][2], tostring(res))
        end

        ::continue::
    end

    if (#errors > 0) then
        -- return false, errors
        return false, error_wrapper:new(self, errors)
    end

    return true
end

function sqlite_ad:create_from_dump(db_path, dump_path, close_after_creating)
    os.execute('rm -f ' .. db_path)

    local db, err_code, err_msg = sqlite.open(db_path)

    if (not db) then
        -- return false, 'SQLite database creation state: ' .. tostring(err_code) .. '. ' .. err_msg
        return false, error_wrapper:new(self, 'SQLite database creation state: ' .. tostring(err_code) .. '. ' .. err_msg)
    end

    if (not db:isopen()) then
        -- return false, 'db is closed!'
        return false, error_wrapper:new(self, 'db is closed!')
    end

    local dump = lib_file:read(dump_path)
    local db_restore_st = db:exec(dump)

    if (db_restore_st == sqlite.OK) then
        if close_after_creating then
            db:close()
            db = true
        end

        return db, 'SQLite database creation state: done!'
    end

    db:close()

    -- return false, 'SQLite database creation state: restore data from dump is failed!'
    return false, error_wrapper:new(self, 'SQLite database creation state: restore data from dump is failed!')
end

function sqlite_ad:is_exist_table(db, table_name)
    local schema = lib_string:split(table_name, '.')

    if (#schema == 2) then
        table_name = schema[2]
        schema = schema[1]
    else
        schema = 'main'
    end
    
    local stmt = db:prepare([[select name from ]] .. schema .. [[.SQLITE_MASTER where type = 'table' and name = ?;]])

    if (not stmt) then
        return false, error_wrapper:new(self, 'statement error!')
    end

    stmt:bind(1, table_name)
    local query_st = stmt:step()

    if (query_st ~= sqlite.ROW) then
        stmt:finalize()

        return false, error_wrapper:new(self, 'table not exist')
    end

    if (table_name == stmt:get_value(0)) then
        stmt:finalize()

        return true
    end

    stmt:finalize()

    return false, error_wrapper:new(self, 'table not exist')
end

function sqlite_ad:get_col_names(db, table_name)
    local res = {}

    res.exist_table, res.exist_table_err = self:is_exist_table(db, table_name)

    if (not res.exist_table) then
        return false, error_wrapper:chain(self, res.exist_table_err)
    end

    local schema_name = ''
    local table_name_spl = lib_string:split(table_name, '.')

    if (#table_name_spl == 2) then
        schema_name = table_name_spl[1] .. '.'
        table_name = table_name_spl[2]
    elseif(#table_name_spl ~= 1) then
        return false, error_wrapper:new(self, 'Schema name incorrect!')
    end

    local stmt = db:prepare(string.format('PRAGMA %stable_info(%s);', schema_name, table_name))

    if (not stmt) then
        return false, error_wrapper:new(self, 'statement error!')
    end

    res.query_st = stmt:step()

    if (res.query_st ~= sqlite.ROW) then
        stmt:finalize()

        return false, error_wrapper:new(self, 'query state: ' .. query_st)
    end

    res.cols = {}
    --bug or feature? if use stmt:rows(),
    --function starts iteration from second row in statement result data
    res.first_row = stmt:get_values()
    table.insert(res.cols, res.first_row[2])

    for row in stmt:rows() do
        table.insert(res.cols, row[2])
    end

    stmt:finalize()

    return res.cols
end

--todo: check function with one row returns
function sqlite_ad:get_rows(stmt, close_stmt)
    local res = stmt:step()

    if (res ~= sqlite.ROW) then
        stmt:finalize()

        if (res == sqlite.DONE) then
            return {}
        end

        return false, error_wrapper:new(self, res)
    end

    local rows = {}
    --first row
    table.insert(rows, stmt:get_values())

    for row in stmt:rows() do
        table.insert(rows, row)
    end

    if close_stmt then
        stmt:finalize()
        stmt = nil
    end

    return rows
end

--db with attached databases db_name1, db_name2
function sqlite_ad:compare_schema(db, db_name1, db_name2)
    local stmt1 = db:prepare('SELECT sql FROM '.. db_name1 .. '.SQLITE_MASTER WHERE sql != \'\';')
    local stmt2 = db:prepare('SELECT sql FROM '.. db_name2 .. '.SQLITE_MASTER WHERE sql != \'\';')

    if (not stmt1 or not stmt2) then
        return false, error_wrapper:new(self, 'statement error!')
    end

    local master1, master1_err = self:get_rows(stmt1, true)
    local master2, master2_err = self:get_rows(stmt2, true)

    if (not master1 or not master2) then
        return false, error_wrapper:chain(self, master1_err or master2_err)
    end

    if (#master1 ~= #master2) then
        return false, error_wrapper:new(self, 'database schemas don\'t match')
    end

    local hashes1 = {}
    local hashes2 = {}

    for i = 1, #master1 do
        -- hashes1[sha2.hash256(master1[i][1])] = true
        -- hashes2[sha2.hash256(master2[i][1])] = true
        hashes1[sha.sha256(master1[i][1])] = true
        hashes2[sha.sha256(master2[i][1])] = true
    end

    for key in pairs(hashes1) do
        if (not hashes2[key]) then
            return false, error_wrapper:new(self, 'database schemas don\'t match')
        end
    end

    return true
end

function sqlite_ad:select_all(db, table_name)
    local exist_table, exist_table_err = self:is_exist_table(db, table_name)

    if (not exist_table) then
        return false, error_wrapper:chain(self, exist_table_err)
    end

    local stmt = db:prepare('SELECT * FROM ' .. table_name)

    if (not stmt) then
        return false, error_wrapper:new(self, 'statement error!')
    end

    local rows, rows_err = self:get_rows(stmt, true)

    if (not rows) then
        return false, error_wrapper:chain(self, rows_err)
    end

    return rows
end

function sqlite_ad:insert_from_hash(db, table_name, data, values_only)
    local exist_table, exist_table_err = self:is_exist_table(db, table_name)

    if (not exist_table) then
        return false, error_wrapper:chain(self, exist_table_err)
    end

    local query_template = 'INSERT INTO ' .. table_name .. ' VALUES(?, ?);'

    if values_only then
        query_template = 'INSERT INTO ' .. table_name .. ' VALUES(?);'
    end

    local stmt = db:prepare(query_template)

    if (not stmt) then
        return false, error_wrapper:new(self, 'statement error!')
    end

    local function bind_values(key, value)
        stmt:bind(1, key)
        stmt:bind(2, value)
    end

    if values_only then
        bind_values = function(key, value)
            stmt:bind(1, value)
        end
    end

    stmt:bind(1, table_name)

    for k, v in pairs(data) do
        bind_values(k, v)
        local result_msg = stmt:step()

        if (result_msg == sqlite.MISUSE) then
            if (stmt:isopen()) then
                stmt:reset()
                result_msg = stmt:step()
            else
                stmt:finalize()

                return false, error_wrapper:new(self, result_msg)
            end
        elseif (result_msg == sqlite.DONE) then
            stmt:reset()
        elseif (result_msg == sqlite.ERROR) then
            stmt:finalize()

            return false, error_wrapper:new(self, result_msg)
        end
    end

    stmt:finalize()
    stmt = nil

    return true
end

function sqlite_ad:table_to_hash(res_table)
    if (type(res_table) ~= 'table') then
        return false, error_wrapper:new(self, 'res_table must be a table')
    end

    if (#res_table < 1) then
        return {}
    end

    local hash = {}

    for i = 1, #res_table do
        hash[res_table[i][1]] = res_table[i][2]
    end

    return hash
end

function sqlite_ad:insert_from_table(db, table_name, data)
    local exist_table, exist_table_err = self:is_exist_table(db, table_name)

    if (not exist_table) then
        return false, error_wrapper:chain(self, exist_table_err)
    end

    local cols, cols_err = self:get_col_names(db, table_name)

    if (not cols) then
        return false, error_wrapper:chain(self, cols_err)
    end

    local query_template = 'INSERT INTO ' .. table_name .. ' VALUES(' .. string.rep('?', #cols, ', ') .. ');'
    local stmt = db:prepare(query_template)

    if (not stmt) then
        return false, error_wrapper:new(self, 'statement error!')
    end

    local function bind_values(row_data)
        for i=1, #cols do
            stmt:bind(i, row_data[i])
        end
    end

    for i=1, #data do
        bind_values(data[i])
        local result_msg = stmt:step()

        if (result_msg == sqlite.MISUSE) then
            if (stmt:isopen()) then
                stmt:reset()
                result_msg = stmt:step()
            else
                stmt:finalize()

                return false, error_wrapper:new(self, result_msg)
            end
        elseif (result_msg == sqlite.DONE) then
            stmt:reset()
        elseif (result_msg == sqlite.ERROR) then
            stmt:finalize()

            return false, error_wrapper:new(self, result_msg)
        end
    end

    stmt:finalize()
    stmt = nil

    return true
end

return sqlite_ad