local directive = require('lib.tools.directive2')
local error_wrapper = require('lib.tools.error_wrapper')
local lib_file = require('lib.tools.lib_file')
local fs = require('lfs')
local json = require('cjson')
local lib_table = require('lib.tools.lib_table')
local luac = require('lib.tools.luac')
local NEF_PATH = require('lib.tools.NEF_PATH')
local pkg_acl_filter = require('lib.tools.pkg_acl_filter')
local pkg_local_dirs = require('share.pkg_local_dirs')
local posix = require('posix.sys.stat')
local sha = require('lib.sha2')
local sqlite = require('lsqlite3complete')
local sqlite_ad = require('lib.tools.sqlite_ad')
local sqlite3_pcre_path = require('share.sqlite3_pcre_path')
local lib_string = require('lib.tools.lib_string')
local system_signals = require('share.system_signals')
local unistd = require('posix.unistd')

if (not NEF_PATH) then
    error('NEF_PATH not defined!')
end

local lib_pkg = {
    __name = 'lib_pkg'
}

lib_pkg.config_template = require('packages.template.config')

function lib_pkg:get_pkg_path(pkg_name)
    local pkg_path = NEF_PATH .. '/packages/' .. pkg_name

    if (not lib_file:is_exist(pkg_path)) then
        return false, error_wrapper:new(self, 'Package path: ' .. pkg_path .. ' not exist!')
    end

    return pkg_path
end

function lib_pkg:get_pkg_full_path(pkg_name)
    local pkg_path, pkg_path_err = self:get_pkg_path(pkg_name)

    if (not pkg_path) then
        return false, error_wrapper:chain(self, pkg_path_err)
    end

    local pkg_full_path = pkg_path .. '/' .. pkg_name .. '.pkg'

    if (not lib_file:is_exist(pkg_full_path)) then
        return false, error_wrapper:new(self, 'Package file: ' .. pkg_full_path .. ' not exist!')
    end

    return pkg_full_path
end

function lib_pkg:get_pkg_hash(pkg_name)
    local pkg_full_path, pkg_full_path_err = self:get_pkg_full_path(pkg_name)

    if (not pkg_full_path) then
        return false, error_wrapper:chain(self, pkg_full_path_err)
    end

    local pkg = lib_file:read(pkg_full_path)

    if (not pkg) then
        return false, error_wrapper:new(self, 'Package file ' .. pkg_full_path .. ' reading error')
    end

    return sha.sha256(pkg) -- sha2.hash256(pkg)
end

-- function lib_pkg:get_exports_bc(src, exports_list)
--     local exports, exports_err = directive:get_lists('exports', src)

--     if (not exports) then
--         return false, error_wrapper:chain(self, exports_err)
--     end

--     --make exports list to sql table format
--     for i=1, #exports do
--         if (#exports[i] < 3) then
--             goto continue
--         end

--         table.insert(exports_list, {exports[i][1], exports[i][2]}) --property, comment
--         table.remove(exports[i], 1)
--         table.remove(exports[i], 1)
--         exports_list[#exports_list][3] = json.encode(exports[i]) --options

--         ::continue::
--     end

--     return true
-- end

function lib_pkg:get_exports_bc(src, exports_list)
    local exports, exports_err = directive:get_targs('define_export', src)

    if (not exports) then
        return false, error_wrapper:chain(self, exports_err)
    end

    --make exports list to sql table format
    for i=1, #exports do
        if (#exports[i] < 3) then
            goto continue
        end

        table.insert(exports_list, {exports[i][1], exports[i][2]}) --property, comment
        table.remove(exports[i], 1)
        table.remove(exports[i], 1)
        exports_list[#exports_list][3] = json.encode(exports[i]) --options

        ::continue::
    end

    return true
end

function lib_pkg:get_events_bc(src, file_path, events_list, pkg_config)
    local file_name = string.sub(file_path, 12) -- "./services/"
    local services_map = lib_table:map_hash(pkg_config.services)
    local service_name = ''
    local events, events_err = directive:get_targs('define_event', src)

    if (not events) then
        return false, error_wrapper:chain(self, events_err)
    end

    if (not services_map[file_name]) then
        return false, error_wrapper:new(self, 'service name not defined!')
    end

    service_name = services_map[file_name]

    --make events list to sql table format
    local function add_to_list(event)
        table.insert(events_list, {
            event.name,
            service_name,
            json.encode(event)
        })
    end

    if (type(service_name) == 'table') then
        add_to_list = function(event)
            local schema = json.encode(event)

            for i=1, #service_name do
                table.insert(events_list, {
                    event.name,
                    service_name[i],
                    schema
                })
            end
        end
    end

    for i=1, #events do
        if  (not events[i]['name']) then
            goto continue
        end

        add_to_list(events[i])

        ::continue::
    end

    return true
end

function lib_pkg:chk_config(pkg_config)
    if (type(pkg_config) ~= 'table') then
        return false, error_wrapper:new(self, 'pkg_config must be a table!')
    end

    local errors = {}
    lib_table:compare_by_template(self.config_template, pkg_config, errors)
    lib_table:compare_by_template(self.config_template.main, pkg_config.main, errors)

    if (#errors > 0) then
        return false, error_wrapper:new(self, errors)
    end

    return true
end

--проверяет правила из списка acl на его корректность в пакете
--проверять перед добавлением acl_list в пакет или в проект
function lib_pkg:filter_acl(db, acl_list)
    local services, services_err = self:get_services(db)
    local modules, modules_err = self:get_modules(db)
    local events, events_err = self:get_events_hash(db)

    if (not acl_list) then
        return false, error_wrapper:new(self, 'acl_list not defined!')
    end

    if (not services) then
        return false, error_wrapper:chain(self, services_err)
    end

    if (not modules) then
        return false, error_wrapper:chain(self, modules_err)
    end

    if (not events) then
        return false, error_wrapper:chain(self, events_err)
    end

    local filtered_acl, filtered_acl_err = pkg_acl_filter:filter(acl_list, modules, services, system_signals, events)

    if (not filtered_acl) then
        return false, error_wrapper:chain(self, filtered_acl_err)
    end

    return filtered_acl
end

function lib_pkg:chk_pkg_schema(db, res)
    res.template_filename = NEF_PATH .. '/packages/template/template.pkg'

    res.attach_template, res.attach_template_err = sqlite_ad:attach(db, {
        ['template'] = res.template_filename
    })

    if (not res.attach_template) then
        return false, error_wrapper:chain(self, res.attach_template_err)
    end

    res.compare_schema, res.compare_schema_err = sqlite_ad:compare_schema(db, 'main', 'template')
    res.detach_template, res.detach_template_err = sqlite_ad:detach(db, 'template')

    if (not res.detach_template) then
        return false, error_wrapper:chain(self, res.detach_template_err)
    end

    if (not res.compare_schema) then
        return false, error_wrapper:chain(self, res.compare_schema_err)
    end

    return true
end

function lib_pkg:chk_pkg_config(db, res)
    res.config, res.config_err = self:get_config(db)

    if (not res.config) then
        return false, error_wrapper:chain(self, res.config_err)
    end

    res.config_errors = {}
    lib_table:compare_by_template(self.config_template.main, res.config, res.config_errors)

    if (#res.config_errors > 0) then
        return false, error_wrapper:new(self, res.config_errors)
    end

    return true
end

function lib_pkg:chk_pkg_files(db, res)
    res.t_files, res.t_files_err = sqlite_ad:select_all(db, 'files')

    if (not res.t_files) then
        return false, error_wrapper:chain(self, res.t_files_err)
    end

    res.files, res.files_hashes, res.files_hashes_errors, res.services, res.modules = {}, {}, {}, {}, {}

    --res.services, res.modules соответственно
    res.path_hooks = {
        ['services'] = true,
        ['modules'] = true
    }

    for i=1, #res.t_files do
        res.files[res.t_files[i][1]] = res.t_files[i][2]
        res.files_hashes[res.t_files[i][1]] = res.t_files[i][3]
        local subs = lib_string:split(res.t_files[i][1], '/')
        
        --согласно конфигу пакета, в директориях services и modules не допускаются вложения
        --файлы находятся в корне этих директорий, поэтому захардкожено как subs[3]
        if (#subs > 2 and res.path_hooks[subs[2]]) then
            res[subs[2]][subs[3]] = true
        end
    end

    for file_path, hash in pairs(res.files_hashes) do
        local hash2 = sha.sha256(res.files[file_path]) -- sha2.hash256(res.files[file_path])

        if (hash ~= hash2) then
            error_wrapper:add(res.files_hashes_errors, file_path, 'file changed!')
        end
    end

    if (#res.files_hashes_errors > 0) then
        return false, error_wrapper:new(self, res.files_hashes_errors)
    end

    return true
end

function lib_pkg:chk_pkg_services(db, res)
    if (not res.services) then
        return false, error_wrapper:new(self, 'res.services not defined! Run chk_pkg_files.')
    end

    if (not res.config) then
        return false, error_wrapper:new(self, 'res.config not defined! Run chk_pkg_config.')
    end

    res.t_services, res.t_services_err = self:get_services(db)

    if (not res.t_services) then
        return false, error_wrapper:chain(self, res.t_services_err)
    end
    
    res.services_errors = {}

    for service, filename in pairs(res.t_services) do
        if (not res.services[filename]) then
            error_wrapper:add(res.services_errors, service, './services/' .. filename .. ' not found')
        end
    end

    if (#res.services_errors > 0) then
        return false, error_wrapper:new(self, res.services_errors)
    end

    if (not res.t_services[res.config.name]) then
        return false, error_wrapper:new(self, 'default service not defined!')
    end

    return true
end

function lib_pkg:chk_pkg_modules(db, res)
    if (not res.modules) then
        return false, error_wrapper:new(self, 'res.modules not defined! Run chk_pkg_files.')
    end

    res.t_modules, res.t_modules_err = self:get_modules(db)

    if (not res.t_modules) then
        return false, error_wrapper:chain(self, res.t_modules_err)
    end
    
    res.modules_errors = {}

    for module, filename in pairs(res.t_modules) do
        if (not res.modules[filename]) then
            error_wrapper:add(res.modules_errors, module, './modules/' .. filename .. ' not found')
        end
    end

    if (#res.modules_errors > 0) then
        return false, error_wrapper:new(self, res.modules_errors)
    end

    return true
end

function lib_pkg:chk_pkg_autoload_modules(db, res)
    if (not res.modules) then
        return false, error_wrapper:new(self, 'res.modules not defined! Run chk_pkg_files.')
    end

    res.autoload_modules, res.autoload_modules_err = self:get_autoload_modules(db)

    if (not res.autoload_modules) then
        return false, error_wrapper:chain(self, res.autoload_modules_err)
    end
    
    res.autoload_modules_errors = {}

    for i=1, #res.autoload_modules do
        if (not res.modules[res.autoload_modules[i]]) then
            error_wrapper:add(
                res.autoload_modules_errors,
                tostring(res.autoload_modules[i]),
                tostring(res.autoload_modules[i]) .. ' not found in modules'
            )
        end
    end

    if (#res.autoload_modules_errors > 0) then
        return false, error_wrapper:new(self, res.autoload_modules_errors)
    end

    return true
end

function lib_pkg:chk_pkg_acl(db, res)
    if (not res.t_modules) then
        return false, error_wrapper:new(self, 'res.t_modules not defined! Run chk_pkg_modules.')
    end

    if (not res.t_services) then
        return false, error_wrapper:new(self, 'res.t_services not defined! Run chk_pkg_services.')
    end

    res.acl_list, res.acl_list_err = self:get_acl(db)

    if (not res.acl_list) then
        return false, error_wrapper:chain(self, res.acl_list_err)
    end

    res.events, res.events_err = self:get_events_hash(db)

    if (not res.events) then
        return false, error_wrapper:chain(self, res.events_err)
    end

    res.filtered_acl, res.filtered_acl_err = pkg_acl_filter:filter(
        res.acl_list,
        res.t_modules,
        res.t_services,
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

function lib_pkg:chk(db, debug_mode)
    local res = {}

    res.chk_pkg_schema, res.chk_pkg_schema_err = self:chk_pkg_schema(db, res)

    if (not res.chk_pkg_schema) then
        return false, error_wrapper:chain(self, res.chk_pkg_schema_err), debug_mode and res
    end

    res.chk_pkg_config, res.chk_pkg_config_err = self:chk_pkg_config(db, res)

    if (not res.chk_pkg_config) then
        return false, error_wrapper:chain(self, res.chk_pkg_config_err), debug_mode and res
    end

    res.chk_pkg_files, res.chk_pkg_files_err = self:chk_pkg_files(db, res)

    if (not res.chk_pkg_files) then
        return false, error_wrapper:chain(self, res.chk_pkg_files_err), debug_mode and res
    end

    res.chk_pkg_services, res.chk_pkg_services_err = self:chk_pkg_services(db, res)

    if (not res.chk_pkg_services) then
        return false, error_wrapper:chain(self, res.chk_pkg_services_err), debug_mode and res
    end

    res.chk_pkg_modules, res.chk_pkg_modules_err = self:chk_pkg_modules(db, res)

    if (not res.chk_pkg_modules) then
        return false, error_wrapper:chain(self, res.chk_pkg_modules_err), debug_mode and res
    end

    res.chk_pkg_autoload_modules, res.chk_pkg_autoload_modules_err = self:chk_pkg_autoload_modules(db, res)

    if (not res.chk_pkg_autoload_modules) then
        return false, error_wrapper:chain(self, res.chk_pkg_autoload_modules_err), debug_mode and res
    end

    res.chk_pkg_acl, res.chk_pkg_acl_err = self:chk_pkg_acl(db, res)

    if (not res.chk_pkg_acl) then
        return false, error_wrapper:chain(self, res.chk_pkg_acl_err), debug_mode and res
    end

    --убираем файлы для сокращения объема вывода отладки
    res.t_files = nil
    res.files = nil

    return true, _, debug_mode and res
end

function lib_pkg:open(pkg_name)
    local pkg_full_path, pkg_full_path_err = self:get_pkg_full_path(pkg_name)

    if (not pkg_full_path) then
        return false, error_wrapper:chain(self, pkg_full_path_err)
    end

    local pkg_db, err_code, err_msg = sqlite.open(pkg_full_path)

    if (not pkg_db) then
        return false, error_wrapper:new(self, 'SQLite database state: ' .. tostring(err_code) .. '. ' .. err_msg)
    end

    if (not pkg_db:isopen()) then
        return false, error_wrapper:new(self, 'package db is closed!')
    end

    pkg_db:exec('PRAGMA foreign_keys=ON;')

    return pkg_db
end

function lib_pkg:create(pkg_config, close_after_creating)
    local chk_config, chk_config_err = self:chk_config(pkg_config)

    if (not chk_config) then
        return false, error_wrapper:chain(self, chk_config_err)
    end

    if (#pkg_config.main.name < 2) then
        return false, error_wrapper:new(self, 'Package name must be at least 2 characters!')
    end

    local db, db_err = sqlite_ad:create_from_dump(
        NEF_PATH .. '/packages/' .. pkg_config.main.name .. '/' .. pkg_config.main.name .. '.pkg',
        NEF_PATH .. '/packages/template/template.dump.sql',
        close_after_creating
    )

    if (not db) then
        return false, error_wrapper:chain(self, db_err)
    end
    
    return db
end

function lib_pkg:add_config(db, pkg_config)
    -- menu item
    if (pkg_config.main.type == '1' and pkg_config.main.menu_item) then
        pkg_config.main.menu_item = json.encode(pkg_config.main.menu_item)
    end

    local insert_from_hash, insert_from_hash_err = sqlite_ad:insert_from_hash(db, 'config', pkg_config.main)

    if (not insert_from_hash) then
        return false, error_wrapper:chain(self, insert_from_hash_err)
    end

    return insert_from_hash
end

function lib_pkg:get_config(db)
    local t_config, t_config_err = sqlite_ad:select_all(db, 'config')

    if (not t_config) then
        return false, error_wrapper:chain(self, t_config_err)
    end

    local config, config_err = sqlite_ad:table_to_hash(t_config)

    if (not config) then
        return false, error_wrapper:chain(self, config_err)
    end

    return config
end

function lib_pkg:add_files(db, pkg_config, debug_mode)
    local res = {
        ['errors'] = {
            ['events'] = {},
            ['exports'] = {},
            ['file'] = {},
            ['luac'] = {}
        },
        ['events'] = {},
        ['exports'] = {},
        ['files'] = {}
    }

    res.chk_config, res.chk_config_err = self:chk_config(pkg_config)

    if (not res.chk_config) then
        return false, error_wrapper:chain(self, res.chk_config_err), debug_mode and res
    end
    
    local pkg_path, pkg_path_err = self:get_pkg_path(pkg_config.main.name)

    if (not pkg_path) then
        return false, error_wrapper:chain(self, pkg_path_err), debug_mode and res
    end

    res.cur_dir, res.cur_dir_err = fs.currentdir()

    if (not res.cur_dir) then
        return false, error_wrapper:new(self, 'Can`t get current directory! ' .. res.cur_dir_err), debug_mode and res
    end

    if (not fs.chdir(pkg_path)) then
        return false, error_wrapper:new(self, 'Can`t chdir to ' .. pkg_path), debug_mode and res
    end

    local stmt = db:prepare('INSERT INTO files VALUES(?, ?, ?);')

    if (not stmt) then
        return false, error_wrapper:new(self, 'statement error!'), debug_mode and res
    end

    local function add(path, exc_dir)
        for filename in fs.dir(path) do
            if (filename == '.' or filename == '..') then
                goto continue
            end

            local file_path = path..'/'.. filename

            if pkg_config.file_exceptions[file_path] then
                goto continue
            end

            if (fs.attributes(file_path).mode == 'file') then
                if (not pkg_config.luac_exceptions[file_path] and not exc_dir) then
                    local f_content, f_err = luac(file_path)

                    if (not f_content) then
                        table.insert(res.errors.luac, {
                            ['parameter'] = 'luac',
                            ['error'] = 'file: ' .. file_path .. '.\n' .. f_err
                        })

                        goto continue
                    end

                    local f_hash = sha.sha256(f_content) -- sha2.hash256(f_content)

                    if (string.sub(file_path, -4) == '.lua') then
                        file_path = string.sub(file_path, 1, -5)
                    end

                    table.insert(res.files, {
                        file_path,
                        f_content,
                        f_hash
                    })

                    --add exports from services
                    --add events from services
                    if (string.match(file_path, '^(./services/)')) then
                        local ev, ev_err = self:get_events_bc(f_content, file_path, res.events, pkg_config)
                        local ex, ex_err = self:get_exports_bc(f_content, res.exports)
                        
                        if (not ev) then
                            error_wrapper:add(res.errors.events, 'get_events', ev_err)
                        end

                        if (not ex) then
                            error_wrapper:add(res.errors.exports, 'get_exports', ex_err)
                        end
                    end
                else
                    local f_content = lib_file:read(file_path)

                    if (not f_content) then
                        table.insert(res.errors.file, {
                            ['parameter'] = 'lib_file:read',
                            ['error'] = 'file: ' .. file_path .. ' reading error'
                        })

                        goto continue
                    end

                    local f_hash = sha.sha256(f_content) --sha2.hash256(f_content)

                    table.insert(res.files, {
                        file_path,
                        f_content,
                        f_hash
                    })
                end

                goto continue
            end

            if (fs.attributes(file_path).mode == 'directory') then
                local exc_dir = false

                if pkg_config.luac_exceptions[file_path] then
                    exc_dir = true
                end

                add(file_path, exc_dir)
            end

            ::continue::
        end
    end

    add('.')

    if (not fs.chdir(res.cur_dir)) then
        return false, error_wrapper:new(self, 'Can`t chdir to ' .. res.cur_dir), debug_mode and res
    end

    res.insert_files, res.insert_files_err = sqlite_ad:insert_from_table(db, 'files', res.files)

    if (not res.insert_files) then
        return false, error_wrapper:chain(self, res.insert_files_err), debug_mode and res
    end

    if (#res.events > 0) then
        res.insert_events, res.insert_events_err = sqlite_ad:insert_from_table(db, 'events', res.events)

        if (not res.insert_events) then
            return false, error_wrapper:chain(self, res.insert_events_err), debug_mode and res
        end
    end

    if (#res.exports > 0) then
        res.insert_exports, res.insert_exports_err = sqlite_ad:insert_from_table(db, 'exports', res.exports)

        if (not res.insert_exports) then
            return false, error_wrapper:chain(self, res.insert_exports_err), debug_mode and res
        end
    end

    --убираем файлы для сокращения объема вывода отладки
    res.files = nil

    return true, _, debug_mode and res
end

function lib_pkg:get_files(db)
    local stmt = db:prepare('SELECT filename, data FROM files')

    if (not stmt) then
        return false, error_wrapper:new(self, 'statement error!')
    end

    local t_files, t_files_err = sqlite_ad:get_rows(stmt, true)

    if (not t_files) then
        return false, error_wrapper:chain(self, t_files_err)
    end

    local files, files_err = sqlite_ad:table_to_hash(t_files)

    if (not files) then
        return false, error_wrapper:chain(self, files_err)
    end

    return files
end

function lib_pkg:extract_local_files(db)
    if (not db:load_extension(sqlite3_pcre_path)) then
        return false, error_wrapper:new(self, 'error loading sqlite3-pcre')
    end

    local package_name, package_name_err = self:get_property(db, 'name')

    if (not package_name) then
        return false, error_wrapper:chain(self, package_name_err)
    end

    local query  = 'SELECT filename, data FROM files WHERE filename REGEXP \'^(%s/)\''
    local errors = {}

    for dir in pairs(pkg_local_dirs) do
        for row in db:rows(string.format(query, dir)) do
            local path_list = lib_string:split(row[1], '/')

            if (#path_list ~= 3) then
                error_wrapper:add(errors, row[1], 'empty directories or multilevel directories are not allowed')

                goto continue
            end

            local local_path = string.format('%s/%s/%s', NEF_PATH, path_list[2], package_name)
            local local_full_path = string.format('%s/%s/%s/%s', NEF_PATH, path_list[2], package_name, path_list[3])

            if (not lib_file:is_exist(local_path)) then
                if (posix.mkdir(local_path) ~= 0) then
                    error_wrapper:add(errors, local_path, 'mkdir error')

                    goto continue
                end
            end

            if (not lib_file:write(local_full_path, row[2])) then
                error_wrapper:add(errors, local_full_path, 'write error')
            end

            ::continue::
        end
    end

    if (#errors > 0) then
        return false, error_wrapper:new(self, errors)
    end

    return true
end

function lib_pkg:remove_local_files(db)
    if (not db:load_extension(sqlite3_pcre_path)) then
        return false, error_wrapper:new(self, 'error loading sqlite3-pcre')
    end

    local package_name, package_name_err = self:get_property(db, 'name')

    if (not package_name) then
        return false, error_wrapper:chain(self, package_name_err)
    end

    local query  = 'SELECT filename FROM files WHERE filename REGEXP \'^(%s/)\''
    local errors = {}
    local local_dirs = {}

    for dir in pairs(pkg_local_dirs) do
        for row in db:rows(string.format(query, dir)) do
            local path_list = lib_string:split(row[1], '/')

            if (#path_list ~= 3) then
                error_wrapper:add(errors, row[1], 'empty directories or multilevel directories are not allowed')

                goto continue
            end

            local local_path = string.format('%s/%s/%s', NEF_PATH, path_list[2], package_name)
            local local_full_path = string.format('%s/%s/%s/%s', NEF_PATH, path_list[2], package_name, path_list[3])

            if (not lib_file:is_exist(local_full_path)) then
                error_wrapper:add(errors, local_full_path, 'file not exist')

                goto continue
            end

            local_dirs[local_path] = true

            if (unistd.unlink(local_full_path) ~= 0) then
                error_wrapper:add(errors, local_full_path, 'file remove error')
            end

            ::continue::
        end
    end

    if (#errors > 0) then
        return false, error_wrapper:new(self, errors)
    end

    for dir in pairs(local_dirs) do
        if (unistd.rmdir(dir) ~= 0) then
            error_wrapper:add(errors, dir, 'rmdir error')
        end
    end

    if (#errors > 0) then
        return false, error_wrapper:new(self, errors)
    end

    return true
end

function lib_pkg:get_property(db, property)
    local stmt = db:prepare('SELECT value FROM config WHERE property = ?;')

    if (not stmt) then
        return false, error_wrapper:new(self, 'statement error!')
    end

    stmt:bind(1, property)
    local res = stmt:step()

    if (res ~= sqlite.ROW) then
        return false, error_wrapper:new(self, 'property ' .. tostring(property) .. ' not exist')
    end

    local value = stmt:get_value(0)
    stmt:finalize()

    return value
end

function lib_pkg:add_acl(db, pkg_config)
    local filtered_acl, filtered_acl_err = self:filter_acl(db, pkg_config.acl)

    if (not filtered_acl) then
        return false, error_wrapper:chain(self, filtered_acl_err)
    end

    local insert_from_table, insert_from_table_err = sqlite_ad:insert_from_table(db, 'acl', filtered_acl)

    if (not insert_from_table) then
        return false, error_wrapper:chain(self, insert_from_table_err)
    end

    return insert_from_table
end

function lib_pkg:get_acl(db)
    local acl, acl_err = sqlite_ad:select_all(db, 'acl')

    if (not acl) then
        return false, error_wrapper:chain(self, acl_err)
    end

    return acl
end

function lib_pkg:get_events(db)
    local events, events_err = sqlite_ad:select_all(db, 'events')

    if (not events) then
        return false, error_wrapper:chain(self, events_err)
    end

    return events
end

function lib_pkg:get_events_hash(db)
    local stmt = db:prepare('SELECT event, service_name FROM events')

    if (not stmt) then
        return false, error_wrapper:new(self, 'statement error!')
    end

    local t_events, t_events_err = sqlite_ad:get_rows(stmt, true)

    if (not t_events) then
        return false, error_wrapper:chain(self, t_events_err)
    end

    local events, events_err = sqlite_ad:table_to_hash(t_events)

    if (not events) then
        return false, error_wrapper:chain(self, events_err)
    end

    return events
end

function lib_pkg:get_exports(db)
    local t_exports, t_exports_err = sqlite_ad:select_all(db, 'exports')

    if (not t_exports) then
        return false, error_wrapper:chain(self, t_exports_err)
    end

    local exports = {}

    for i=1, #t_exports do
        exports[t_exports[i][1]] = {
            ['comment'] = t_exports[i][2],
            ['options'] = json.decode(t_exports[i][3])
        }
    end

    return exports
end

function lib_pkg:add_services(db, pkg_config)
    local insert_from_hash, insert_from_hash_err = sqlite_ad:insert_from_hash(db, 'services', pkg_config.services)

    if (not insert_from_hash) then
        return false, error_wrapper:chain(self, insert_from_hash_err)
    end

    return insert_from_hash
end

function lib_pkg:get_services(db)
    local t_services, t_services_err = sqlite_ad:select_all(db, 'services')

    if (not t_services) then
        return false, error_wrapper:chain(self, t_services_err)
    end

    local services, services_err = sqlite_ad:table_to_hash(t_services)

    if (not services) then
        return false, error_wrapper:chain(self, services_err)
    end

    return services
end

function lib_pkg:add_modules(db, pkg_config)
    local insert_from_hash, insert_from_hash_err = sqlite_ad:insert_from_hash(db, 'modules', pkg_config.modules)

    if (not insert_from_hash) then
        return false, error_wrapper:chain(self, insert_from_hash_err)
    end

    return insert_from_hash
end

function lib_pkg:get_modules(db)
    local t_modules, t_modules_err = sqlite_ad:select_all(db, 'modules')

    if (not t_modules) then
        return false, error_wrapper:chain(self, t_modules_err)
    end

    local modules, modules_err = sqlite_ad:table_to_hash(t_modules)

    if (not modules) then
        return false, error_wrapper:chain(self, modules_err)
    end

    return modules
end

function lib_pkg:add_autoload_modules(db, pkg_config)
    local insert_from_hash, insert_from_hash_err = sqlite_ad:insert_from_hash(db, 'autoload_modules', pkg_config.autoload_modules, true)

    if (not insert_from_hash) then
        return false, error_wrapper:chain(self, insert_from_hash_err)
    end

    return insert_from_hash
end

-- function lib_pkg:get_autoload_modules(db)
--     local t_autoload_modules, t_autoload_modules_err = sqlite_ad:select_all(db, 'autoload_modules')

--     if (not t_autoload_modules) then
--         return false, error_wrapper:chain(self, t_autoload_modules_err)
--     end

--     local autoload_modules, autoload_modules_err = sqlite_ad:table_to_hash(t_autoload_modules)

--     if (not autoload_modules) then
--         return false, error_wrapper:chain(self, autoload_modules_err)
--     end

--     return autoload_modules
-- end
function lib_pkg:get_autoload_modules(db, raw_format)
    local autoload_modules, autoload_modules_err = sqlite_ad:select_all(db, 'autoload_modules')

    if (not autoload_modules) then
        return false, error_wrapper:chain(self, autoload_modules_err)
    end

    if raw_format then
        return autoload_modules
    end

    for i=1, #autoload_modules do
        autoload_modules[i] = autoload_modules[i][1]
    end

    return autoload_modules
end

function lib_pkg:add_file(db, filename, data)
    if (type(filename) ~= 'string') then
        return false, error_wrapper:new(self, 'filename must be a string')
    end

    if (type(data) ~= 'string' and type(data) ~= 'userdata') then
        return false, error_wrapper:new(self, 'data must be a string or userdata')
    end

    local hash = sha.sha256(data) -- sha2.hash256(data)
    local query = 'INSERT OR REPLACE INTO files (filename, data, hash) VALUES(?, ?, ?);'
    local stmt = db:prepare(query)

    if (not stmt) then
        return false, error_wrapper:new(self, 'statement error!')
    end

    stmt:bind(1, filename)
    stmt:bind(2, data)
    stmt:bind(3, hash)
    local res = stmt:step()
    stmt:finalize()

    if (res == sqlite.DONE) then
        return true
    end

    return false, error_wrapper:new(self, 'SQLite exec error: ' .. tostring(res))
end

function lib_pkg:get_file(db, filename)
    if (type(filename) ~= 'string') then
        return false, error_wrapper:new(self, 'filename must be a string')
    end

    local query = 'SELECT data FROM files WHERE filename = ?;'
    local stmt = db:prepare(query)

    if (not stmt) then
        return false, error_wrapper:new(self, 'statement error!')
    end

    stmt:bind(1, filename)

    local t_file, t_file_err = sqlite_ad:get_rows(stmt, true)

    if (not t_file) then
        return false, error_wrapper:chain(self, t_file_err)
    end

    if (#t_file == 0) then
        return false, error_wrapper:new(self, 'file not found')
    end

    return t_file[1][1]
end

return lib_pkg