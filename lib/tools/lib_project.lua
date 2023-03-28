local error_wrapper = require('lib.tools.error_wrapper')
local lib_file = require('lib.tools.lib_file')
local iso639_1_codes = require('share.languages_iso_codes')
local netresource = require('lib.tools.netresource')
local NEF_PATH = require('lib.tools.NEF_PATH')
local lib_pkg = require('lib.tools.lib_pkg')
local lib_string = require('lib.tools.lib_string')
local pkg_acl_filter = require('lib.tools.pkg_acl_filter')
local pkg_local_dirs = require('share.pkg_local_dirs')
local sha = require('lib.sha2')
local sqlite = require('lsqlite3complete')
local sqlite_ad = require('lib.tools.sqlite_ad')
local sqlite3_pcre_path = require('share.sqlite3_pcre_path')
local system_signals = require('share.system_signals')
local valua = require('lib.valua')

if (not NEF_PATH) then
    error('NEF_PATH not defined!')
end

local lib_project = {
    __name = 'lib_project'
}

lib_project.config_validator = {
    ['lang'] = function(lang, errors)
        if (not valua:new().type('string').len(2, 2)(lang)) then
            error_wrapper:add(errors, 'lang', 'lang type error!')
        end

        if (not iso639_1_codes[lang]) then
            error_wrapper:add(errors, 'lang', 'lang does not match lang code in iso639_1_codes!')
        end
    end,
    ['scheme'] = function(scheme, errors)
        local schemes = {
            ['http'] = true,
            ['https'] = true
        }

        if (not valua:new().type('string').len(4, 5)(scheme)) then
            error_wrapper:add(errors, 'scheme', 'scheme type error!')
        end

        if (not schemes[scheme]) then
            error_wrapper:add(errors, 'scheme', 'invalid scheme!')
        end
    end,
    ['base_url'] = function(host, errors)
        local is_base_url = false

        if (valua._ip(host)) then
            is_base_url = true
        end

        if (not is_base_url and valua._ip(host, true)) then
            is_base_url = true
        end

        if (not is_base_url and netresource:is_fqdn(host)) then
            is_base_url = true
        end

        if (not is_base_url and netresource:is_fqdn(host, true)) then
            is_base_url = true
        end

        if (not is_base_url) then
            error_wrapper:add(errors, 'base_url', 'parameter does not match ip address or hostname!')
        end
    end,
    ['scontroller_url'] = function(url, errors)
        if (url:match('[^%w%.%,%:%;%*%+%-_%/%$%&%\'%~%!]')) then
            error_wrapper:add(errors, 'scontroller_url', 'invalid url!')
        end
    end,
    ['css_url'] = function(url, errors)
        if (not netresource:is_url(url, true)) then
            error_wrapper:add(errors, 'css_url', 'invalid url!')
        end
    end,
    ['js_url'] = function(url, errors)
        if (not netresource:is_url(url, true)) then
            error_wrapper:add(errors, 'js_url', 'invalid url!')
        end
    end
}

function lib_project:add_schema_prefix(project_name)
    if (type(project_name) ~= 'string') then
        return ''
    end

    if (project_name == 'main') then
        return ''
    end
    
    return project_name .. '.'
end

function lib_project:chk(template_filename, project_filename)
    local res = {}
    local db = sqlite:open_memory()

    if (not db:isopen()) then
        return false, error_wrapper:new(self, 'db is closed!')
    end

    res.attach, res.attach_err = sqlite_ad:attach(db, {
        ['template'] = template_filename,
        ['project'] = project_filename
    })

    if (not res.attach) then
        db:close()

        return false, error_wrapper:chain(self, res.attach_err)
    end

    res.compare_schema, res.compare_schema_err = sqlite_ad:compare_schema(db, 'template', 'project')

    if (not res.compare_schema) then
        sqlite_ad:detach_all(db)
        db:close()

        return false, error_wrapper:chain(self, res.compare_schema_err)
    end

    res.template_config, res.template_config_err = sqlite_ad:select_all(db, 'template.config')
    res.project_config, res.project_config_err = sqlite_ad:select_all(db, 'project.config')
    sqlite_ad:detach_all(db)
    db:close()
    
    if (not res.template_config) then
        return false, error_wrapper:chain(self, res.template_config_err, 'template_config')
    end

    if (not res.project_config) then
        return false, error_wrapper:chain(self, res.project_config_err, 'project_config')
    end

    res.template_config = sqlite_ad:table_to_hash(res.template_config)
    res.project_config = sqlite_ad:table_to_hash(res.project_config)

    res.validation_errors = {}

    for parameter, value in pairs(res.template_config) do
        if (not res.project_config[parameter]) then
            error_wrapper:add(res.validation_errors, parameter, 'not defined!')

            goto continue
        end

        if (type(res.project_config[parameter]) ~= type(value)) then
            error_wrapper:add(res.validation_errors, parameter, 'type error')

            goto continue
        end

        -- config validation
        if (not self.config_validator[parameter]) then
            goto continue
        end

        self.config_validator[parameter](res.project_config[parameter], res.validation_errors)

        ::continue::
    end

    if (#res.validation_errors > 0) then
        return false, error_wrapper:new(self, res.validation_errors)
    end

    return true
end

function lib_project:create_main()
    local create_from_dump, create_from_dump_err = sqlite_ad:create_from_dump(
        NEF_PATH .. '/project/main.prj',
        NEF_PATH .. '/project/main_template.dump.sql',
        true
    )

    if (not create_from_dump) then
        return false, error_wrapper:chain(self, create_from_dump_err)
    end

    return create_from_dump
end

function lib_project:chk_main()
    local chk, chk_err = self:chk(
        NEF_PATH .. '/project/main_template.prj',
        NEF_PATH .. '/project/main.prj'
    )

    if (not chk) then
        return false, error_wrapper:chain(self, chk_err)
    end

    return chk
end

function lib_project:register_project(main, project_name)
    local stmt = main:prepare('INSERT OR REPLACE INTO main.projects (name) VALUES(?);')

    if (not stmt) then
        return false, error_wrapper:new(self, 'statement error!')
    end

    stmt:bind(1, project_name)
    local res = stmt:step()
    stmt:finalize()

    if (res == sqlite.DONE) then
        return true
    end

    return false, error_wrapper:new(self, tostring(res))
end

function lib_project:create_project(main, project_name)
    local project_ok, project_err = sqlite_ad:create_from_dump(
        NEF_PATH .. '/project/' .. project_name .. '.prj',
        NEF_PATH .. '/project/template.dump.sql',
        true
    )

    if (not project_ok) then
        return false, error_wrapper:chain(self, project_err)
    end

    local register_project, register_project_err = self:register_project(main, project_name)

    if (not register_project) then
        return false, error_wrapper:chain(self, register_project_err)
    end

    return register_project
end

function lib_project:chk_project(project_filename)
    local chk, chk_err = self:chk(
        NEF_PATH .. '/project/template.prj',
        project_filename
    )

    if (not chk) then
        return false, error_wrapper:chain(self, chk_err)
    end

    return chk
end

function lib_project:open_project(main, project_name)
    local project_filename = NEF_PATH .. '/project/' .. tostring(project_name) .. '.prj'
    local chk_project, chk_project_err = self:chk_project(project_filename)

    if (not chk_project) then
        return false, error_wrapper:chain(self, chk_project_err)
    end

    local attach, attach_err = sqlite_ad:attach(main, {[project_name] = project_filename})

    if (not attach) then
        return false, error_wrapper:chain(self, attach_err)
    end

    return true
end

function lib_project:open_main()
    local chk_main, chk_main_err = self:chk_main()

    if (not chk_main) then
        return false, error_wrapper:chain(self, chk_main_err)
    end

    local main, err_code, err_msg = sqlite.open(NEF_PATH .. '/project/main.prj')

    if (not main) then
        return false, error_wrapper:new(self, 'SQLite database state: ' .. tostring(err_code) .. '. ' .. err_msg)
    end

    if (not main:isopen()) then
        return false, error_wrapper:new(self, 'main project db is closed!')
    end

    main:exec('PRAGMA foreign_keys=ON;')

    local projects, projects_err = sqlite_ad:select_all(main, 'projects')

    if (not projects) then
        return false, error_wrapper:chain(self, projects_err)
    end

    local errors = {}

    for i = 1, #projects do
        local project, project_err = self:open_project(main, projects[i][1])

        if (not project) then
            error_wrapper:add(errors, projects[i][1], tostring(project_err))
        end
    end

    if (#errors > 0) then
        return false, error_wrapper:new(self, errors)
    end

    return main
end

function lib_project:add_property(main, project_name, property, value)
    local stmt = main:prepare('INSERT OR REPLACE INTO ' .. project_name .. '.config (property, value) VALUES(?, ?);')

    if (not stmt) then
        return false, error_wrapper:new(self, 'statement error!')
    end

    stmt:bind(1, property)
    stmt:bind(2, value)
    local res = stmt:step()
    stmt:finalize()

    if (res == sqlite.DONE) then
        if (self:get_project_priority(main, project_name) < 1 and project_name ~= 'main') then
            return self:add_property(main, 'main', property, value)
        end

        return true
    end

    return false, error_wrapper:new(self, 'SQLite exec error: ' .. tostring(res))
end

function lib_project:delete_property(main, project_name, property)
    local stmt = main:prepare('DELETE FROM ' .. project_name .. '.config WHERE property = ?;')

    if (not stmt) then
        return false, error_wrapper:new(self, 'statement error!')
    end

    stmt:bind(1, property)
    local res = stmt:step()
    stmt:finalize()

    if (res == sqlite.DONE) then
        if (self:get_project_priority(main, project_name) < 1 and project_name ~= 'main') then
            return self:delete_property(main, 'main', property)
        end

        return true
    end

    return false, error_wrapper:new(self, 'SQLite exec error: ' .. tostring(res))
end

function lib_project:get_property(main, project_name, property)
    local stmt = main:prepare('SELECT value FROM ' .. project_name .. '.config WHERE property = ?;')

    if (not stmt) then
        return false, error_wrapper:new(self, 'statement error!')
    end

    stmt:bind(1, property)
    local res = stmt:step()

    if (res ~= sqlite.ROW) then
        return false, error_wrapper:new(self, 'SQLite exec error: ' .. tostring(res))
    end

    local value = stmt:get_value(0)
    stmt:finalize()

    if (not type(value)) then
        return false, error_wrapper:new(self, 'lib_project:get_property==> Property is nil')
    end

    return value
end

function lib_project:get_projects(main)
    local res, err = sqlite_ad:select_all(main, 'main.projects')

    if (not res) then
        return false, error_wrapper:chain(self, err)
    end

    local projects = {}

    for i = 1, #res do
        projects[res[i][1]] = true
    end

    return projects
end

function lib_project:get_project_priority(main, project_name)
    local priority = self:get_property(main, project_name, 'project_priority')

    if (not priority) then
        return 0
    end

    if (tonumber(priority) and tonumber(priority) > 0) then
        return 1
    end

    return 0
end

function lib_project:set_project_priority(main, project_name, priority)
    if (type(priority) ~= 'number') then
        priority = 0
    end

    if (priority > 0) then
        priority = 1
    else
        priority = 0
    end

    local add_property, add_property_err = self:add_property(main, project_name, 'project_priority', priority)

    if (not add_property) then
        return false, error_wrapper:chain(self, add_property_err)
    end

    return true
end

function lib_project:get_config(main, project_name)
    local res, err = sqlite_ad:select_all(main, project_name .. '.config')

    if (not res) then
        return false, error_wrapper:chain(self, err)
    end

    local hash, hash_err = sqlite_ad:table_to_hash(res)

    if (not hash) then
        return false, error_wrapper:chain(self, hash_err)
    end

    return hash
end

function lib_project:diff_configs_by_priority(main, project_name, priority)
    if (not priority) then
        return false, error_wrapper:new(self, 'priority not defined!')
    end

    if (type(priority) ~= 'number') then
        return false, error_wrapper:new(self, 'priority must be a number!')
    end

    local query = 'SELECT * FROM %sconfig EXCEPT SELECT * FROM %sconfig;'

    local p1 = self:add_schema_prefix('main')
    local p2 = self:add_schema_prefix(project_name)

    if (priority > 0) then
        p1, p2 = p2, p1
    end

    query = string.format(query, p1, p2)

    local stmt = main:prepare(query)

    if (not stmt) then
        return false, error_wrapper:new(self, 'statement error!')
    end

    local rows, rows_err = sqlite_ad:get_rows(stmt, true)

    if (not rows) then
        return false, error_wrapper:chain(self, rows_err)
    end

    return sqlite_ad:table_to_hash(rows)
end

function lib_project:get_pkg_info(main, pkg_name, hash)
    local query = 'SELECT * FROM main.packages WHERE name = ?;'

    if (hash and type(hash) == 'string' and #hash >= 64) then
        query = 'SELECT * FROM main.packages WHERE (name = ?) OR (hash = ?);'
    else
        hash = nil
    end

    local stmt = main:prepare(query)

    if (not stmt) then
        return false, error_wrapper:new(self, 'statement error!')
    end

    stmt:bind(1, pkg_name)

    if hash then
        stmt:bind(2, hash)
    end

    local res = stmt:step()

    if (res ~= sqlite.ROW) then
        stmt:finalize()

        if (res == sqlite.DONE) then
            return false, error_wrapper:new(self, 'not found')
        end

        return false, error_wrapper:new(self, tostring(res))
    end

    local pkg_info = stmt:get_values()
    stmt:finalize()

    return pkg_info
end

--pkg_info = {package name, package version, package hash}
function lib_project:add_pkg_info(main, pkg_info)
    if (type(pkg_info) ~= 'table') then
        return false, error_wrapper:new(self, 'pkg_info must be a table!')
    end

    if (#pkg_info ~= 3) then
        return false, error_wrapper:new(self, 'pkg_info structure error')
    end

    local ex_pkg_info, ex_pkg_info_err = self:get_pkg_info(main, pkg_info[1], pkg_info[3])

    if ex_pkg_info then
        return false, error_wrapper:new(self, 'Package alredy installed!')
    end

    if (ex_pkg_info_err.error ~= 'not found') then
        return false, error_wrapper:chain(self, ex_pkg_info_err)
    end

    pkg_info[4] = 'locked'
    local res, err = sqlite_ad:insert_from_table(main, 'packages', {pkg_info})

    if (not res) then
        return false, error_wrapper:chain(self, err)
    end

    local projects, projects_err = self:get_projects(main)

    if (not projects) then
        return false, error_wrapper:chain(self, projects_err)
    end

    local errors = {}

    for project_name in pairs(projects) do
        local res, err = sqlite_ad:insert_from_hash(main, project_name .. '.packages', {[pkg_info[1]] = pkg_info[4]})

        if (not res) then
            error_wrapper:add(errors, project_name, err)
        end
    end

    if (#errors > 0) then
        return false, error_wrapper:new(self, errors)
    end

    return true
end

--Сделал параметром для поиска именно hash
--т.к. при работе с несколькими инстансами
--имя пакета из локально поддерживаемых репозиториев
--может пересекаться с именами пакетов в официальном.
--Пакет может быть удален по невнимательности.
function lib_project:delete_pkg_info(main, hash)
    local pkg_info, pkg_info_err = self:get_pkg_info(main, '', hash)

    if (not pkg_info) then
        return false, error_wrapper:chain(self, pkg_info_err)
    end

    local stmt = main:prepare('DELETE FROM main.packages WHERE hash = ?;')

    if (not stmt) then
        return false, error_wrapper:new(self, 'statement error!')
    end

    stmt:bind(1, hash)
    local res = stmt:step()
    stmt:finalize()

    if (res ~= sqlite.DONE) then
        return false, error_wrapper:new(self, tostring(res))
    end

    local projects, projects_err = self:get_projects(main)

    if (not projects) then
        return false, error_wrapper:chain(self, projects_err)
    end

    local errors = {}

    for project_name in pairs(projects) do
        local stmt = main:prepare('DELETE FROM ' .. project_name .. '.packages WHERE name = ?')

        if (not stmt) then
            error_wrapper:add(errors, project_name, 'statement error!')

            goto continue
        end

        stmt:bind(1, pkg_info[1])
        local res = stmt:step()
        stmt:finalize()

        if (res ~= sqlite.DONE) then
            error_wrapper:add(errors, project_name, tostring(res))
        end

        ::continue::
    end

    if (#errors > 0) then
        return false, error_wrapper:new(self, errors)
    end

    return true
end

function lib_project:set_pkg_status(main, project_name, pkg_name, status)
    local pkg_info, pkg_info_err = self:get_pkg_info(main, pkg_name)

    if (not pkg_info) then
        return false, error_wrapper:chain(self, pkg_info_err)
    end

    if (not ({['installed'] = true, ['locked'] = true})[status]) then
        return false, error_wrapper:new(self, 'Status must be "installed" or "locked"')
    end

    local projects = {}

    if (project_name ~= 'main' and self:get_project_priority(main, project_name) > 0) then
        projects[project_name] = true
    else
        projects, projects_err = self:get_projects(main)

        if (not projects) then
            return false, error_wrapper:chain(self, projects_err)
        end

        projects['main'] = true
    end

    local errors = {}
    
    for project_name in pairs(projects) do
        local stmt = main:prepare(string.format('UPDATE %spackages SET status = ? WHERE name = ?;', self:add_schema_prefix(project_name)))

        if (not stmt) then
            error_wrapper:add(errors, project_name, 'statement error!')

            goto continue
        end

        stmt:bind(1, status)
        stmt:bind(2, pkg_name)
        local res = stmt:step()
        stmt:finalize()

        if (res == sqlite.BUSY) then
            error_wrapper:add(errors, project_name, 'Project database is busy, sql err code: ' .. tostring(res))

            goto continue
        end

        if (res ~= sqlite.DONE) then
            error_wrapper:add(errors, project_name, tostring(res))
        end

        ::continue::
    end

    if (#errors > 0) then
        return false, error_wrapper:new(self, errors)
    end

    return true
end

function lib_project:add_dependency_field(main, pkg_name, dep_pkg_name)
    local stmt = main:prepare('INSERT OR REPLACE INTO dependencies (package, dep_package) VALUES(?, ?);')

    if (not stmt) then
        return false, error_wrapper:new(self, 'statement error!')
    end

    stmt:bind(1, pkg_name)
    stmt:bind(2, dep_pkg_name)
    local res = stmt:step()
    stmt:finalize()
    stmt = nil

    if (res == sqlite.DONE) then
        return true
    end

    return false, error_wrapper:new(self, 'SQL executing error: ' .. tostring(res))
end

function lib_project:delete_dependency_field(main, pkg_name, dep_pkg_name)
    local stmt = main:prepare('DELETE FROM main.dependencies WHERE package = ? AND dep_package = ?;')

    if (not stmt) then
        return false, error_wrapper:new(self, 'statement error!')
    end

    stmt:bind(1, pkg_name)
    stmt:bind(2, dep_pkg_name)
    local res = stmt:step()
    stmt:finalize()
    stmt = nil

    if (res == sqlite.DONE) then
        return true
    end

    return false, error_wrapper:new(self, 'SQL executing error: ' .. tostring(res))
end

--mode: lu (level up)- get packages dependent on the specified package, ld - (level down) get only package dependencies
-- all - lu + ld option by default
function lib_project:get_dependencies(main, pkg_name, mode)
    mode = mode or 'all'
    local queries = {
        ['all'] = [[WITH RECURSIVE
                        i(j) AS (
                            VALUES(?)
                            UNION
                            SELECT package FROM main.dependencies, i WHERE dep_package = i.j
                        ),
                        k(v) AS (
                            VALUES(?)
                            UNION
                            SELECT dep_package FROM main.dependencies, k WHERE package = k.v
                        )
                    SELECT package FROM main.dependencies WHERE dep_package IN i
                    UNION
                    SELECT dep_package FROM main.dependencies WHERE package IN k;]],
        ['lu'] = [[WITH RECURSIVE
                        r(n) AS (
                            VALUES(?)
                            UNION
                            SELECT package FROM dependencies, r WHERE dep_package = r.n
                        )
                  SELECT package FROM dependencies WHERE dep_package IN r;]],
        ['ld'] = [[WITH RECURSIVE
                        r(n) AS (
                            VALUES(?)
                            UNION
                            SELECT dep_package FROM dependencies, r WHERE package = r.n
                        )
                  SELECT dep_package FROM dependencies WHERE package IN r;]]
    }

    local stmt = main:prepare(queries[mode])

    if (not stmt) then
        return false, error_wrapper:new(self, 'statement error!')
    end

    if (mode == 'all') then
        stmt:bind(1, pkg_name)
        stmt:bind(2, pkg_name)
    else
        stmt:bind(1, pkg_name)
    end

    local rows, rows_err = sqlite_ad:get_rows(stmt, true)

    if (not rows) then
        return false, error_wrapper:chain(self, rows_err)
    end

    local dependencies = {}

    for i=1, #rows do
        dependencies[rows[i][1]] = true
    end

    dependencies[pkg_name] = nil

    return dependencies
end

function lib_project:compare_dependency_records(main, pkg_name, pkg_config_dependencies)
    if (type(pkg_config_dependencies) ~= 'string') then
        return false, error_wrapper:new(self, 'pkg_config_dependencies must be a string')
    end

    pkg_config_dependencies = lib_string:split(pkg_config_dependencies, ',')
    local dependencies, dependencies_err = self:get_dependencies(main, pkg_name, 'ld')

    if (not dependencies) then
        return false, error_wrapper:chain(self, dependencies_err)
    end

    local errors = {}

    for i=1, #pkg_config_dependencies do
        if (not dependencies[pkg_config_dependencies[i]]) then
            error_wrapper:add(errors, pkg_config_dependencies[i],'no database record in main project')
        end
    end

    if (#errors > 0) then
        return false, errors
    end

    return true
end

function lib_project:rset_pkg_status(main, project_name, pkg_name, status)
    local dependencies, dependencies_err = self:get_dependencies(main, pkg_name)
    local errors = {}

    if (not dependencies) then
        return false, error_wrapper:chain(self, dependencies_err)
    end

    for dependency, _ in pairs(dependencies) do
        local set_pkg_status, set_pkg_status_err = self:set_pkg_status(main, project_name, dependency, status)

        if (not set_pkg_status) then
            error_wrapper:add(errors, string.format('lib_project:rset_pkg_status==>%s', dependency), set_pkg_status_err)
        end
    end

    if (#errors > 0) then
        return false, errors
    end

    return true
end

function lib_project:get_keys(main)
    local stmt = main:prepare('SELECT * FROM key_store;')

    if (not stmt) then
        return false, error_wrapper:new(self, 'statement error!')
    end

    local rows, rows_err = sqlite_ad:get_rows(stmt, true)

    if (not rows) then
        return false, error_wrapper:chain(self, rows_err)
    end

    local keys = {}

    for i=1, #rows do
        if (not keys[rows[i][1]]) then
            keys[rows[i][1]] = {}
        end

        keys[rows[i][1]][rows[i][2]] = rows[i][3]
    end

    return keys
end

function lib_project:add_key(main, pkg_name, key, value)
    local pkg_info, pkg_info_err = self:get_pkg_info(main, pkg_name)

    if (not pkg_info) then
        return false, error_wrapper:chain(self, pkg_info_err)
    end

    local stmt = main:prepare('INSERT OR REPLACE INTO main.key_store (package, key, value) VALUES(?, ?, ?);')

    if (not stmt) then
        return false, error_wrapper:new(self, 'statement error!')
    end

    stmt:bind(1, pkg_name)
    stmt:bind(2, key)
    stmt:bind(3, value)
    local res = stmt:step()
    stmt:finalize()

    if (res == sqlite.DONE) then
        return true
    end

    return false, error_wrapper:new(self, tostring(res))
end

function lib_project:delete_key(main, pkg_name, key)
    local stmt = main:prepare('DELETE FROM main.key_store WHERE (package = ?) AND (key = ?);')

    if (not stmt) then
        return false, error_wrapper:new(self, 'statement error!')
    end

    stmt:bind(1, pkg_name)
    stmt:bind(2, key)
    local res = stmt:step()
    stmt:finalize()

    if (res == sqlite.DONE) then
        return true
    end

    return false, error_wrapper:new(self, tostring(res))
end

function lib_project:get_acl(main, project_name, pkg_name)
    local query = string.format('SELECT * FROM acl UNION SELECT * FROM %sacl', self:add_schema_prefix(project_name))

    if pkg_name then
        query = string.format('SELECT source_type,source,target_type,target FROM (%s) WHERE package = \'%s\';', query, pkg_name)
    end

    local stmt = main:prepare(query)

    if (not stmt) then
        return false, error_wrapper:new(self, 'statement error!')
    end

    local rows, rows_err = sqlite_ad:get_rows(stmt, true)

    if (not rows) then
        return false, error_wrapper:chain(self, rows_err)
    end

    return rows
end

function lib_project:add_acl(main, project_name, pkg_db, acl_list)
    local pkg_name, pkg_name_err = lib_pkg:get_property(pkg_db, 'name')

    if (not pkg_name) then
        return false, error_wrapper:chain(self, pkg_name_err)
    end

    local pkg_info, pkg_info_err = self:get_pkg_info(main, pkg_name)

    if (not pkg_info) then
        return false, error_wrapper:chain(self, pkg_info_err)
    end

    local filtered_acl, filtered_acl_err = lib_pkg:filter_acl(pkg_db, acl_list)

    if (not filtered_acl) then
        return false, error_wrapper:chain(self, filtered_acl_err)
    end

    for i=1, #filtered_acl do
        table.insert(filtered_acl[i], 1, pkg_name)
    end

    local add_project_acl, add_project_acl_err = sqlite_ad:insert_from_table(
        main,
        self:add_schema_prefix(project_name) .. 'acl',
        filtered_acl
    )

    if (not add_project_acl) then
        return false, error_wrapper:chain(self, add_project_acl_err)
    end

    if (self:get_project_priority(main, project_name) > 0) then
        return true
    end

    local add_main_acl, add_main_acl_err = sqlite_ad:insert_from_table(main, 'main.acl', filtered_acl)

    if (not add_main_acl) then
        return false, error_wrapper:chain(self, add_main_acl_err)
    end

    return true
end

function lib_project:delete_acl(main, pkg_name)
    local pkg_info, pkg_info_err = self:get_pkg_info(main, pkg_name)

    if (not pkg_info) then
        return false, error_wrapper:chain(self, pkg_info_err)
    end

    local projects, projects_err = self:get_projects(main)
    
    if (not projects) then
        return false, error_wrapper:chain(self, projects_err)
    end

    projects.main = true
    --statement не создается т.к меняться будет только имя таблицы, биндинг возможен только в выражениях
    local query = 'DELETE FROM %s.acl WHERE package = \'' .. pkg_name .. '\';'
    local errors = {}

    for project in pairs(projects) do
        local res = main:exec(string.format(query, project))

        if (res ~= sqlite.DONE) then
            error_wrapper:add(errors, project, tostring(res))
        end
    end

    if (#errors > 0) then
        return false, error_wrapper:new(self, errors)
    end

    return true
end

function lib_project:chk_acl(main, project_name, pkg_name, pkg_db, res)
    res.acl_list, res.acl_list_err = self:get_acl(main, project_name, pkg_name)

    if (not res.acl_list) then
        return false, error_wrapper:chain(self, res.acl_list_err)
    end

    res.services, res.services_err = lib_pkg:get_services(pkg_db)

    if (not res.services) then
        return false, error_wrapper:chain(self, res.services_err)
    end

    res.modules, res.modules_err = lib_pkg:get_modules(pkg_db)

    if (not res.modules) then
        return false, error_wrapper:chain(self, res.modules_err)
    end

    res.events, res.events_err = lib_pkg:get_events_hash(pkg_db)

    if (not res.events) then
        return false, error_wrapper:chain(self, res.events_err)
    end

    res.filtered_acl, res.filtered_acl_err = pkg_acl_filter:filter(
        res.acl_list,
        res.modules,
        res.services,
        system_signals,
        res.events
    )

    if (not res.filtered_acl) then
        return false, error_wrapper:chain(self, res.filtered_acl_err)
    end

    res.acl_errors = pkg_acl_filter:diff_lists(res.acl_list, res.filtered_acl)
    
    if (#res.acl_errors > 0) then
        return false, error_wrapper:new(self, res.acl_errors)
    end

    return true
end

function lib_project:chk_local_files(pkg_name, pkg_db, res)
    if (not pkg_db:load_extension(sqlite3_pcre_path)) then
        return false, error_wrapper:new(self, 'error loading sqlite3-pcre')
    end

    local query  = 'SELECT filename, hash FROM files WHERE filename REGEXP \'^(%s/)\''
    res.local_files_errors = {}

    for dir in pairs(pkg_local_dirs) do
        for row in pkg_db:rows(string.format(query, dir)) do
            local path_list = lib_string:split(row[1], '/')

            if (#path_list ~= 3) then
                error_wrapper:add(
                    res.local_files_errors,
                    row[1],
                    'empty directories or multilevel directories are not allowed'
                )

                goto continue
            end

            local local_full_path = string.format('%s/%s/%s/%s', NEF_PATH, path_list[2], pkg_name, path_list[3])

            if (not lib_file:is_exist(local_full_path)) then
                error_wrapper:add(res.local_files_errors, local_full_path, 'not exist')
    
                goto continue
            end

            local local_file = lib_file:read(local_full_path)
    
            if (not local_file) then
                error_wrapper:add(res.local_files_errors, local_full_path, 'read error')
    
                goto continue
            end

            if (row[2] ~= sha.sha256(local_file)) then -- if (row[2] ~= sha2.hash256(local_file)) then
                error_wrapper:add(res.local_files_errors, local_full_path, 'file changed')
            end

            ::continue::
        end
    end

    if (#res.local_files_errors > 0) then
        return false, error_wrapper:new(self, res.local_files_errors)
    end

    return true
end

function lib_project:chk_install(main, project_name, pkg_name, pkg_db, debug_mode)
    local res = {}

    res.pkg_hash, res.pkg_hash_err = lib_pkg:get_pkg_hash(pkg_name)

    if (not res.pkg_hash) then
        return false, error_wrapper:chain(self, res.pkg_hash_err), debug_mode and res
    end

    res.pkg_config, res.pkg_config_err = lib_pkg:get_config(pkg_db)

    if (not res.pkg_config) then
        return false, error_wrapper:chain(self, res.pkg_config_err), debug_mode and res
    end

    if (pkg_name ~= res.pkg_config.name) then
        return false, error_wrapper:new(self, 'pkg_name and pkg_config.name does not match')
    end

    res.pkg_info, res.pkg_info_err = self:get_pkg_info(main, pkg_name)

    if (not res.pkg_info) then
        if (res.pkg_info_err.error == 'not found') then
            return 'not installed', _, debug_mode and res
        end

        return false, error_wrapper:chain(self, res.pkg_info_err), debug_mode and res
    end

    --column 3 is a package hash
    if (res.pkg_hash ~= res.pkg_info[3]) then
        return false, error_wrapper:new(self, 'changed'), debug_mode and res
    end

    res.chk_acl, res.chk_acl_err = self:chk_acl(main, project_name, pkg_name, pkg_db, res)

    if (not res.chk_acl) then
        return false, error_wrapper:chain(self, res.chk_acl_err), debug_mode and res
    end

    res.chk_local_files, res.chk_local_files_err = self:chk_local_files(pkg_name, pkg_db, res)

    if (not res.chk_local_files) then
        return false, error_wrapper:chain(self, res.chk_local_files_err), debug_mode and res
    end

    res.status = 'installed'

    if (res.pkg_info[4] == 'locked') then
        res.status = 'locked'
    end

    return res.status, _, debug_mode and res
end

function lib_project:get_autoload_modules(main, project_name)
    local query = string.format('SELECT * FROM autoload_modules UNION SELECT * FROM %sautoload_modules;', self:add_schema_prefix(project_name))

    if (self:get_project_priority(main, project_name) > 0) then
        query = string.format('SELECT * FROM %sautoload_modules;', self:add_schema_prefix(project_name))
    end

    local stmt = main:prepare(query)
    
    if (not stmt) then
        return false, error_wrapper:new(self, 'statement error!')
    end

    local rows, rows_err = sqlite_ad:get_rows(stmt, true)

    if (not rows) then
        return false, error_wrapper:chain(self, rows_err)
    end

    for i=1, #rows do
        rows[i] = rows[i][1] .. '.' .. rows[i][2]
    end

    return rows
end

function lib_project:add_autoload_modules(main, project_name, pkg_db)
    local pkg_name, pkg_name_err = lib_pkg:get_property(pkg_db, 'name')

    if (not pkg_name) then
        return false,  error_wrapper:chain(self, pkg_name_err)
    end

    local pkg_info, pkg_info_err = self:get_pkg_info(main, pkg_name)

    if (not pkg_info) then
        return false, error_wrapper:chain(self, pkg_info_err)
    end

    local autoload_modules, autoload_modules_err = lib_pkg:get_autoload_modules(pkg_db, true)

    if (not autoload_modules) then
        return false, error_wrapper:chain(self, autoload_modules_err)
    end

    for i=1, #autoload_modules do
        table.insert(autoload_modules[i], 1, pkg_name)
    end

    local add_project_autoload_modules, add_project_autoload_modules_err = sqlite_ad:insert_from_table(
        main,
        self:add_schema_prefix(project_name) .. 'autoload_modules',
        autoload_modules
    )

    if (not add_project_autoload_modules) then
        return false, error_wrapper:chain(self, add_project_autoload_modules_err, 'project_autoload_modules')
    end

    if (self:get_project_priority(main, project_name) > 0) then
        return true
    end

    local add_main_autoload_modules, add_main_autoload_modules_err = sqlite_ad:insert_from_table(main, 'autoload_modules', autoload_modules)

    if (not add_main_autoload_modules) then
        return false, error_wrapper:chain(self, add_main_autoload_modules_err, 'main_autoload_modules')
    end

    return true
end

function lib_project:delete_autoload_modules(main, project_name, pkg_name)
    local pkg_info, pkg_info_err = self:get_pkg_info(main, pkg_name)

    if (not pkg_info) then
        return false, error_wrapper:chain(self, pkg_info_err)
    end

    local query = 'DELETE FROM %sautoload_modules WHERE package = \'%s\';'
    local res = main:exec(string.format(query, self:add_schema_prefix(project_name), pkg_name))

    if (res ~= sqlite.DONE) then
        return false, error_wrapper:new(self, 'SQLite exec error: ' .. tostring(res))
    end

    res = false

    if (self:get_project_priority(main, project_name) > 0) then
        return true
    end

    res = main:exec(string.format(query, '', pkg_name))

    if (res == sqlite.DONE) then
        return true
    end

    return false, error_wrapper:new(self, 'SQLite exec error: ' .. tostring(res))
end

return lib_project