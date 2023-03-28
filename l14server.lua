-- Nellstare app server v. 14.0
-- Autor: Senin Stanislav 2017

package.path = '?;?.lua;/usr/local/share/lua/5.4/?.lua;/usr/local/share/lua/5.4/?/init.lua;/usr/local/lib/lua/5.4/?.lua;/usr/local/lib/lua/5.4/?/init.lua'
package.cpath = '/usr/local/lib/lua/5.4/?.so;/usr/local/lib/lua/5.4/?'

args = {...}

-- workaround for sandboxing
do
    local _require = require

    require = function(lib_name)
        local lib = _require(lib_name)
        package.loaded[lib_name] = nil
        package.preload[lib_name] = nil

        return lib
    end
end
-- workaround for sandboxing

local base64 = require('lib.base64') --; base64.alpha("base64url")
local lbcp = require('lbcp2')
local directive = require('lib.tools.directive2')
local deepcopy = require('lib.tools.deepcopy')
local error_wrapper = require('lib.tools.error_wrapper')
local ev = require('ev')
local fs = require('lfs')
local gp = require('lib.tools.gp')
local hmac = require('openssl.hmac')
local json = require('cjson')
local lib_file = require('lib.tools.lib_file')
local lib_pkg = require('lib.tools.lib_pkg')
local lib_project = require('lib.tools.lib_project')
local lib_string = require('lib.tools.lib_string')
local NEF_PATH = require('lib.tools.NEF_PATH')
local posix_signal = require('posix.signal')
local pretty_json = require('lib.tools.pretty_json')
local server_request = require('lib.server_request')
local socket = require('posix.sys.socket')
local sqlite = require('lsqlite3complete')
local sqlite_ad = require('lib.tools.sqlite_ad')
local tcp_server = require('lib.tcp_server')
local unistd = require('posix.unistd')

local lserver = {
    log_path = NEF_PATH .. '/log',
    project_name = 'main',
    project_priority = 0,
    say_cb = print,
    __name = 'lserver'
}

function lserver:say(message)
    self.say_cb(os.date("%Y.%m.%d-%H:%M:%S =>"), message)
end

function lserver:info(server_name)
    server_name = server_name or 'Server_1'
    self:say('Nellstare framework v.0.14 2023\n' .. server_name)
end

function lserver:read_pid(project_name, log_path)
    log_path = log_path or self.log_path
    local pid_file = lib_file:read(string.format('%s/%s.pid',log_path, project_name))

    if (not pid_file) then
        return false, error_wrapper:new(self, 'Pid file reading error')
    end

    return pid_file
end

function lserver:write_pid(project_name, log_path)
    log_path = log_path or self.log_path
    local res = lib_file:write(string.format('%s/%s.pid',log_path, project_name), unistd.getpid())

    if (not res) then
        return false, error_wrapper:new(self, 'Pid file writing error')
    end

    return true
end

-- TODO: get packages from main project if project priority < 1
function lserver:get_packages_list(main, project_name)
    local stmt = main:prepare(string.format(
        'SELECT name FROM packages WHERE name IN (SELECT name FROM %spackages WHERE status = \'installed\');',
        lib_project:add_schema_prefix(project_name)
    ))

    if (not stmt) then
        return false, error_wrapper:new(self, 'statement error')
    end

    local t_packages_list, t_packages_list_err = sqlite_ad:get_rows(stmt, true)

    if (not t_packages_list) then
        return false, error_wrapper:chain(self, t_packages_list_err)
    end

    local packages_list = {}

    for i=1, #t_packages_list do
        packages_list[i] = t_packages_list[i][1]
    end

    return packages_list
end

function lserver:prepare_acl(main, project_name)
    local drop_temp_acl = main:exec('DROP TABLE IF EXISTS t_acl;')

    if (drop_temp_acl ~= sqlite.OK) then
        return false, error_wrapper:new(self, 'SQL execution error:' .. tostring(drop_temp_acl))
    end

    local query = 'CREATE TEMP TABLE t_acl AS SELECT * FROM acl UNION SELECT * FROM %sacl;'
    local temp_acl = main:exec(string.format(query, lib_project:add_schema_prefix(project_name)))

    if (temp_acl ~= sqlite.OK) then
        return false, error_wrapper:new(self, 'SQL execution error:' .. tostring(temp_acl))
    end

    return true
end

function lserver:open_packages(main, project_name, t_packages, packages_list)
    if (type(t_packages) ~= 'table') then
        return false, error_wrapper:new(self, 't_packages must be a table')
    end

    if (type(packages_list) ~= 'table') then
        return false, error_wrapper:new(self, 'packages_list must be a table')
    end

    if (not packages_list) then
        return false, error_wrapper:chain(self, packages_list_err)
    end

    local errors = {}

    for i=1, #packages_list do
        local pkg_err
        t_packages[packages_list[i]], pkg_err = lib_pkg:open(packages_list[i])

        if (not t_packages[packages_list[i]]) then
            error_wrapper:add(errors, packages_list[i], pkg_err)

            goto continue
        end

        local st, st_err, debug = lib_project:chk_install(main, project_name, packages_list[i], t_packages[packages_list[i]])

        if (not st) then
            error_wrapper:add(errors, packages_list[i], st_err)

            goto continue
        end

        if (st ~= 'installed') then
            (t_packages[packages_list[i]]):close_vm();
            -- необходим разделитель ";", lua интерпретирует
            -- открывающуюся скобку, как начало аргументов для вызова
            (t_packages[packages_list[i]]):close()
            t_packages[packages_list[i]] = nil
            error_wrapper:add(errors, packages_list[i], 'Package locked')
        end

        ::continue::
    end

    if (#errors > 0) then
        return false, errors
    end
    
    return true
end

function lserver:close_packages(t_packages)
    if (type(t_packages) ~= 'table') then
        return false, error_wrapper:new(self, 't_packages must be a table')
    end

    for pkg_name, pkg_db in pairs(t_packages) do
        if pkg_db['close_vm'] then
            pkg_db:close_vm()
            pkg_db:close()
        end

        t_packages[pkg_name] = nil
    end

    return true
end

function lserver:get_configs(main, project_name)
    local main_config, main_config_err = lib_project:get_config(main, 'main')

    if (not main_config) then
        return false, error_wrapper:chain(self, main_config_err)
    end

    if (project_name  == 'main') then
        return main_config, main_config
    end
    
    local project_config, project_config_err = lib_project:get_config(main, project_name)

    if (not project_config) then
        return false, error_wrapper:chain(self, project_config_err)
    end

    return main_config, project_config
end

function lserver:read_config()
    local config_res1, config_res2 = self:get_configs(self.main, self.project_name)

    if (not config_res1) then
        return false, error_wrapper:chain(self, config_res2)
    end

    -- в main базе данных значение priority всегда должно равняться 1
    -- это поле необходимо для правильной обработки, если сервер запущен
    -- без опции -p
    self.project_priority = lib_project:get_project_priority(self.main, self.project_name)
    local config_diff, config_diff_err = lib_project:diff_configs_by_priority(self.main, self.project_name, self.project_priority)

    if (not config_diff) then
        return false, error_wrapper:chain(self, config_diff_err)
    end

    self.config = config_res2

    if (self.project_priority > 0) then
        self.config = config_res1
    end

    for property, value in pairs(config_diff) do
        self.config[property] = value
    end

    -- self:say('Diff config:\n' .. pretty_json(config_diff))
    -- self:say('Merged config:\n' .. pretty_json(self.config))

    return true
end

function lserver:fetch_services(pkg_db, pkg_name, keys_map)
    local services_list, services_list_err = lib_pkg:get_services(pkg_db)

    if (not services_list) then
        return false, error_wrapper:chain(self,services_list_err)
    end

    local errors = {}
    local filepath = './services/%s'
    local keys = {}
    local services_files = {}
    local services_list_map = {}

    for service_name, filename in pairs(services_list) do
        if services_list_map[filename] then
            services_files[service_name] = services_files[services_list_map[filename]]

            goto continue
        end

        local data, data_err = lib_pkg:get_file(pkg_db, string.format(filepath, filename))

        if (not data) then
            error_wrapper:add(errors, service_name, data_err)

            goto continue
        end

        services_list_map[filename] = service_name
        services_files[service_name] = data
        keys[service_name] = gp:generate(16)
        keys_map[keys[service_name]] = {['package'] = pkg_name, ['service'] = service_name}

        ::continue::
    end

    if (#errors > 0) then
        keys = nil
        keys_map = nil
        services_files = nil

        return false, errors
    end

    return services_files, keys
end

function lserver:fetch_modules(pkg_db, pkg_name, keys_map)
    local modules_list, modules_list_err = lib_pkg:get_modules(pkg_db)

    if (not modules_list) then
        return false, error_wrapper:chain(self,modules_list_err)
    end

    local errors = {}
    local filepath = './modules/%s'
    local keys = {}
    local modules_bc = {}
    local modules_list_map = {}

    for module_name, filename in pairs(modules_list) do
        if modules_list_map[filename] then
            modules_bc[module_name] = modules_bc[modules_list_map[filename]]

            goto continue
        end

        local data, data_err = lib_pkg:get_file(pkg_db, string.format(filepath, filename))

        if (not data) then
            error_wrapper:add(errors, module_name, data_err)

            goto continue
        end

        modules_list_map[filename] = module_name
        keys[module_name] = gp:generate(16)
        keys_map[keys[module_name]] = {['package'] = pkg_name, ['module'] = module_name}

        local bc_list, bc_list_err = directive:parse(data)
        modules_bc[module_name] = load(data, _, 'b', {})

        if (not bc_list) then
            error_wrapper:add(errors, module_name, bc_list_err)

            goto continue
        end

        for i=1, #bc_list do
            for j=1, #bc_list[i]['constants'] do
                if (directive:get_constant(bc_list[i]['constants'], bc_list[i]['constants'][j][1]) == '${module_key}') then
                    lbcp.setconstant(modules_bc[module_name], bc_list[i]['constants'][j][1], keys[module_name])
                end
            end
        end

        ::continue::
    end

    if (#errors > 0) then
        keys = nil
        keys_map = nil
        modules_bc = nil

        return false, errors
    end

    return modules_bc, keys
end

function lserver:fetch_components(pkg_db)
    if (not pkg_db:load_extension(sqlite3_pcre_path)) then
        return false, error_wrapper:new(self, 'error loading sqlite3-pcre')
    end

    local components_files = {}

    for row in pkg_db:rows('SELECT filename, data FROM files WHERE filename REGEXP \'^(./components/)\'') do
        row[1] = string.gsub(row[1], '^(./components/)', '')
        components_files[row[1]] = row[2]
    end

    return components_files
end

function lserver:mk_instance(main, project_name)
    if (not packages) then
        packages = {}
        services_keys = {}
        services_keys_map = {}
        modules_keys = {}
        modules_keys_map = {}
        tasks = {
            [1] = {
                ['serial'] = os.time(),
                ['tasks'] = 0
            }
        }
    else
        table.insert(tasks, 1, {
            ['serial'] = os.time(),
            ['tasks'] = 0
        })

        modules_keys2 = deepcopy(modules_keys)
        modules_keys_map2 = deepcopy(modules_keys_map)
        services_keys2 = deepcopy(services_keys)
        services_keys_map2 = deepcopy(services_keys_map)
    end

    services = {}
    modules = {}
    autoload_modules = {}
    components = {}
    key_store = {}
    sessions = {}
    cache = {}

    local packages_list, packages_list_err = self:get_packages_list(self.main, self.project_name)

    if (not packages_list) then
        return false, error_wrapper:chain(self, packages_list_err)
    end

    local open_packages, open_packages_err = self:open_packages(self.main, self.project_name, packages, packages_list)

    if (not open_packages) then
        return false, error_wrapper:chain(self, open_packages_err)
    end

    local errors = {}

    for pkg_name, pkg_db in pairs(packages) do
        local s1, s2 = self:fetch_services(pkg_db, pkg_name, services_keys_map)

        if (not s1) then
            error_wrapper:add(errors, pkg_name, s2)

            goto continue
        end

        services[pkg_name], services_keys[pkg_name] = s1, s2

        local m1, m2 = self:fetch_modules(pkg_db, pkg_name, modules_keys_map)

        if (not m1) then
            error_wrapper:add(errors, pkg_name, m2)

            goto continue
        end

        modules[pkg_name], modules_keys[pkg_name] = m1, m2

        local components_err
        components[pkg_name], components_err = self:fetch_components(pkg_db)

        if (not components[pkg_name]) then
            error_wrapper:add(errors, pkg_name, components_err)

            goto continue
        end

        ::continue::
    end

    if (#errors > 0) then
        return false, errors
    end

    -- virtual core package
    modules_keys.core = {['INIT'] = gp:generate(16)}
    modules_keys_map[modules_keys.core['INIT']] = {['package'] = 'core', ['module'] = 'INIT'}

    local close_packages, close_packages_err = self:close_packages(packages)

    if (not close_packages) then
        return false, error_wrapper:chain(self, close_packages_err)
    end

    local prepare_acl, prepare_acl_err = self:prepare_acl(self.main, self.project_name)

    if (not prepare_acl) then
        return false, error_wrapper:chain(self, prepare_acl_err)
    end

    local autoload_modules_err
    autoload_modules, autoload_modules_err = lib_project:get_autoload_modules(self.main, self.project_name)

    if (not autoload_modules) then
        return false, error_wrapper:chain(self, autoload_modules_err)
    end

    key_store, key_store_err = lib_project:get_keys(self.main)

    if (not key_store) then
        return false, error_wrapper:chain(self, key_store_err)
    end

    return true
end

function lserver:normal_exit()
    self:say('Detaching all databases...')
    sqlite_ad:detach_all(self.main)

    self:say('Stop executing all statements...')
    self.main:close_vm()

    self:say('Close main database...')
    self.main:close()

    self:say('Stopping the server...')
    stop_tcp_server()

    self:say(self.config.server_name .. ' stopped normally.')
    os.exit(0)
end

function lserver:init(args)
    for i=1, #args do
        if (args[i] == '-p' and args[i+1]) then
            self.project_name = tostring(args[i+1])
        end

        if (args[i] == '-reload') then
            self.send_reload = true
        end

        if (args[i] == '-stop') then
            self.send_stop = true
        end
    end

    self.main, self.main_err = lib_project:open_main()

    if (not self.main) then
        return false, error_wrapper:chain(self, self.main_err)
    end

    local config_res, config_err = self:read_config()

    if (not config_res) then
        return false, error_wrapper:chain(self, config_err)
    end

    if self.send_reload then
        local reload_req = server_request:new()
        reload_req.host = self.config.host
        reload_req.port = tonumber(self.config.port)
        reload_req.secret = self.config.server_secret
        reload_req.res_len = 150
        reload_req.req = 'reload'
    
        local req_st, res = reload_req:send()
    
        reload_req = nil
    
        if req_st then
            self:say('reload services =>' .. res)
        else
            self:say(res)
        end
    
        os.exit(0)
    end
    
    if self.send_stop then
        local pid = lserver:read_pid(self.project_name)
        local send_sig_res = posix_signal.kill(tonumber(pid), posix_signal.SIGINT)
        self:say('stop server ok: ' .. tostring(send_sig_res))
        os.exit(0)
    end

    self:info(self.config.server_name)
    self:write_pid(self.project_name)

    local mk_instance, mk_instance_err = self:mk_instance(self.main, self.project_name)

    if (not mk_instance) then
        return false, error_wrapper:chain(self, mk_instance_err)
    end

    return true
end

form_handler = {
    __name = 'form_handler'
}

function form_handler:validate(form)
    local package = false
    local source_type = 'module'
    local source = false
    local target_type = false
    local target = false
    
    if (not form.module_key) then
        source_type = 'service'
    elseif modules_keys_map[form.module_key] then
        source = modules_keys_map[form.module_key]['module']
        package = modules_keys_map[form.module_key]['package']
    elseif modules_keys_map2[form.module_key] then
        source = modules_keys_map2[form.module_key]['module']
        package = modules_keys_map2[form.module_key]['package']
    end

    if (source_type == 'service' and form.service_key) then
        if services_keys_map[form.service_key] then
            source = services_keys_map[form.service_key]['service']
            package = services_keys_map[form.service_key]['package']
        elseif services_keys_map2[form.service_key] then
            source = services_keys_map2[form.service_key]['service']
            package = services_keys_map2[form.service_key]['package']
        end
    end

    if (not (package and source_type and source)) then
        return false, 'can\'t get form source field'
    end

    if (not form.target_type) then
        return false, 'target_type not defined!'
    end

    if (type(form.target_type) ~= 'string') then
        return false, 'target_type must be a string'
    end

    if (form.target_type == 'signal' or form.target_type == 'event') then
        target_type = form.target_type
    else
        return false, 'target_type sets incorrect'
    end

    if (not form.target) then
        return false, 'target not defined!'
    end

    if (type(form.target) ~= 'string') then
        return false, 'target must be a string'
    end

    -- условия, когда надо переконвертировать вызов сигнала в acl правило
    if (target_type == 'signal') then
        if (form.target == 'inreq') then
            target_type = 'service'
        end

        if (form.target == 'load_module') then
            target_type = 'module'
        end
    end

    target = form.target

    if (target_type == 'service' or target_type == 'module') then
        if (form.args and form.args.target_path) then
            target = tostring(form.args.target_path)
        else
            return false, 'form.args.target_path not defined!'
        end
    end

    form.package = package
    form.source = source

    return {package, source_type, source, target_type, target}
end

function form_handler:chk_access(acl_rule)
    local main = lserver.main
    local constants_list = {
        ['service'] = "'SERVICES', 'ANY'",
        ['module'] = "'MODULES', 'ANY'",
        ['signal'] = "'SIGNALS'",
        ['event'] = "'EVENTS'"
    }

    local constants_list_k = {
        ['service'] = {
            ['SERVICES'] = true,
            ['ANY'] = true
        },
        ['module'] = {
            ['MODULES'] = true,
            ['ANY'] = true
        },
        ['signal'] = {
            ['SIGNALS'] = true
        },
        ['event'] = {
            ['EVENTS'] = true
        }
    }

    local q1 = string.format(
        "SELECT * FROM t_acl WHERE package = '%s' AND source_type = '%s' AND source = '%s' AND target_type = '%s' AND target = '%s';",
        acl_rule[1],
        acl_rule[2],
        acl_rule[3],
        acl_rule[4],
        acl_rule[5]
    )

    local q2 = string.format(  -- all constants
        "SELECT * FROM t_acl WHERE package = '%s' AND source_type = 'constant' AND source IN (%s) AND target_type = 'constant' AND target IN (%s);",
        acl_rule[1],
        constants_list[acl_rule[2]],
        constants_list[acl_rule[4]]
    )

    -- q2 = string.format(q2, table.unpack(constants_list[acl_rule[2]]), table.unpack(constants_list[acl_rule[4]]))

    local q3 = string.format( -- source as constant
        "SELECT * FROM t_acl WHERE package = '%s' AND source_type = 'constant' AND source IN (%s) AND target_type = '%s' AND target = '%s';",
        acl_rule[1],
        constants_list[acl_rule[2]],
        acl_rule[4],
        acl_rule[5]
    )

    -- q3 = string.format(q3, table.unpack(constants_list[acl_rule[2]]))

    local q4 = string.format( -- target as constant
        "SELECT * FROM t_acl WHERE package = '%s' AND source_type = '%s' AND source = '%s' AND target_type = 'constant' AND target IN (%s);",
        acl_rule[1],
        acl_rule[2],
        acl_rule[3],
        constants_list[acl_rule[4]]
    )

    -- q4 = string.format(q4, table.unpack(constants_list[acl_rule[4]]))
    
    for p, st, s, tt, t in main:urows(q4) do
        if (p == acl_rule[1] and st == acl_rule[2] and s == acl_rule[3] and constants_list_k[acl_rule[4]][t]) then
            return true
        end
    end

    for p, st, s, tt, t in main:urows(q2) do
        if (p == acl_rule[1] and constants_list_k[acl_rule[2]][s] and constants_list_k[acl_rule[4]][t]) then
            return true
        end
    end

    for p, st, s, tt, t in main:urows(q1) do
        if (p == acl_rule[1] and st == acl_rule[2] and s == acl_rule[3] and tt == acl_rule[4] and t == acl_rule[5]) then
            return true
        end
    end

    for p, st, s, tt, t in main:urows(q3) do
        if (p == acl_rule[1] and constants_list_k[acl_rule[2]][s] and tt == acl_rule[4] and t == acl_rule[5]) then
            return true
        end
    end

    return false, 'access denied!'
end

do -- Commands sub
    commands = {}

    function commands:reload()
        local config_res, config_err = lserver:read_config()

        if (not config_res) then
            return pretty_json(config_err)
        end

        lserver:info(lserver.config.server_name)
        local mk_instance, mk_instance_err = lserver:mk_instance(lserver.main, lserver.project_name)

        if (not mk_instance) then
            return pretty_json(mk_instance_err)
        end
  
        return 'ok'
    end

    function commands:stop()
        return 'ok'
    end
end

do -- WS Session sub
    ws_session = {}
    local ws_sessions = {
        ['active'] = {},
        ['inactive'] = {}
    }

    function ws_session:gen_block()

    end
end

do -- Event system sub
    event = {}

    function event.subscribe()

    end

    function event.unsubscribe()

    end

    function event.fire()

    end
end

do -- TCP server sub
    local svc = {}
    -- Signal
    local signal = {
        cache_types = {
            ['string'] = true,
            ['number'] = true,
            ['boolean'] = true
        },
        __name = 'signal'
    }

    function signal.load_module(env, form)
        path_spl = lib_string:split(form.args.target_path, '.')

        if (#path_spl ~= 2) then
            return false, 'can\'t get target_path'
        end

        if modules[path_spl[1]][path_spl[2]] then
            local module_bc = modules[path_spl[1]][path_spl[2]]
            debug.setupvalue(module_bc, 1, env)

            return module_bc
        end
        
        return false, 'module ' .. form.args.target_path .. ' not found'
    end

    function signal.inreq(env, form)
        local req = {
            ['req'] = form.args.target_path,
            ['args'] = form.args
        }

        -- req.args.target_path = nil

        return svc.service_ctl(json.encode(req))
    end

    function signal.get_autoload_modules()
        return deepcopy(autoload_modules)
    end

    function signal.get_key(env, form)
        if (not form.args.key or type(form.args.key) ~= 'string') then
            return false, 'signal.get_key=> form incorrect'
        end

        if (key_store[form.package] and key_store[form.package][form.args.key]) then
            return key_store[form.package][form.args.key]
        end

        return false, 'signal.get_key=> not found'
    end

    function signal.get_cache(env, form)
        if (form.package ~= 'auth' or form.source ~= 'm_auth') then
            return false, 'signal.get_cache=> unautorized request'
        end

        if (not sessions[form.args.usr_id]) then
            sessions[form.args.usr_id] = true
        end

        if (not cache[form.args.usr_id]) then
            cache[form.args.usr_id] = {}
        end

        return deepcopy(cache[form.args.usr_id])
    end

    function signal.save_cache(env, form)
        if (form.package ~= 'auth' or form.source ~= 'm_auth') then
            return false, 'signal.save_cache=> unautorized request'
        end

        if (not sessions[form.args.usr_id]) then
            return false, 'signal.save_cache=> session not autorized'
        end

        for k, v in pairs(form.args.cache) do
            if (not signal.cache_types[type(k)] or not signal.cache_types[type(v)]) then
                goto continue
            end

            cache[form.args.usr_id][k] = v

            ::continue::
        end

        sessions[form.args.usr_id] = nil

        return true
    end

    function signal.get_packages_list()
        local packages_list, packages_list_err = lserver:get_packages_list(lserver.main, lserver.project_name)

        if (not packages_list) then
            return false, 'signal.get_packages_list=> ' .. pretty_json(error_wrapper:chain(self, packages_list_err))
        end

        return packages_list
    end

    -- Service control
    function svc.chk_request(req_str)
        json_ok, req = pcall(json.decode, req_str)

        if (not json_ok) then
            local token = lib_string:split(req_str, '.')

            if (#token ~= 2) then
                lserver:say('Framework=> TCP server=> json err:\n' .. req)

                return false, 'json error'
            end

            local v_hmac = hmac.new(lserver.config.nefsrv_secret, 'sha512')

            if (base64.encode(v_hmac:final(token[1])) ~= token[2]) then
                local v_hmac2 = hmac.new(lserver.config.server_secret, 'sha512')

                if (base64.encode(v_hmac2:final(token[1])) ~= token[2]) then
                    lserver:say('Framework=> TCP server=> token validate err')

                    return false, 'token validate error'
                end

                v_hmac2 = nil
            end

            base64_ok, req_str = pcall(base64.decode, token[1])

            if (not base64_ok) then
                lserver:say('Framework=> TCP server=> token validate err:\n' .. req_str)

                return false, 'base64 error'
            end

            json_ok, req = pcall(json.decode, req_str)

            if (not json_ok) then
                lserver:say('Framework=> TCP server=> token validate err:\n' .. req)

                return false, 'json error'
            end

            v_hmac = nil
            token = nil
            req.type = 'command'
        end

        if (not req.type) then
            req.type = 'service'
        end

        if (not req.req or type(req.req) ~= 'string') then
            lserver:say('Framework=> TCP server=> no request')

            return false, 'no request'
        end

        if (not req.args) then
            req.args = {['meth'] = ''}
        end

        if (req.type == 'service') then
            if req.args.token then
                req.args.token = string.gsub(req.args.token, ' ', '_')
            end

            local req_path = lib_string:split(req.req, '.')

            if (#req_path ~= 2) then
                lserver:say('Framework=> TCP server=> can\'t extract request path from request: ' .. req.req)

                return false, 'request error'
            end

            if (services[req_path[1]] and services[req_path[1]][req_path[2]]) then
                req.package = req_path[1]
                req.service = req_path[2]

                return true, req
            end
        end

        if (req.type == 'command' and commands[req.req]) then
            return true, req
        end

        lserver:say(string.format('Framework=> TCP server=> res: %s not exist\nrequest type: %s', req.req, req.type))

        return false, 'not exist'
    end

    function svc.prepare_env(req)
        local new_env = {
            ['args'] = deepcopy(req.args),
            ['assert'] = function(...) assert(...) end,
            ['config'] = deepcopy(lserver.config),
            ['deepcopy'] = function(...) return deepcopy(...) end,
            ['define_event'] = function(...) end, --fake function uses lib_pkg
            ['define_export'] = function(...) end, --fake function uses lib_pkg
            ['error'] = function(...) return error(...) end,
            ['_form'] = {},
            ['getmetatable'] = function(...) return getmetatable(...) end,
            ['io'] = {},
            ['ipairs'] = function(...) return ipairs(...) end,
            ['load'] = function(...) return load(...) end,
            ['loadfile'] = function(...) return loadfile(...) end,
            ['loadstring'] = function(...) return load(...) end, -- compatible with 5.1
            ['next'] = function(...) return next(...) end,
            ['math'] = {},
            -- ['math'] = w_deepcopy(math),
            ['os'] = {},
            ['pairs'] = function(...) return pairs(...) end,
            ['pcall'] = function(...) return pcall(...) end,
            ['print'] = function(...) return print(...) end, -- only for debug
            ['rawequal'] = function(...) return rawequal(...) end,
            ['rawget'] = function(...) return rawget(...) end,
            ['rawlen'] = function(...) return rawlen(...) end,
            ['rawset'] = function(...) return rawset(...) end,
            ['require'] = {}, -- new require
            ['select'] = function(...) return select(...) end,
            ['service'] = {
                ['cache'] = {},
                ['package_name'] = tostring(req.package), -- передача имени пакета несет потенциальную угрозу!?
                ['name'] = tostring(req.service),
                ['response'] = '',
                ['serial'] = tasks[1]['serial']
            },
            ['setmetatable'] = function(...) return setmetatable(...) end,
            ['string'] = {},
            ['table'] = {},
            ['tonumber'] = function(...) return tonumber(...) end,
            ['tostring'] = function(...) return tostring(...) end,
            ['type'] = function(...) return type(...) end,
            ['utf8'] = {},
            ['warn'] = function(...) return warn(...) end,
            ['xpcall'] = function(...) return xpcall(...) end
        }

        -- delete secrets
        new_env.config.server_secret = nil
        new_env.config.nefsrv_secret = nil

        -- load components
        if components[req.package] then
            new_env.components = deepcopy(components[req.package])
        end

        -- new io
        setmetatable(new_env.io, {
            __index = function(t, k)
                if (k ~= 'io') then
                    t[k] = function(...)
                        local res = table.pack(pcall(io[k], ...))

                        if (res[1] == false) then
                            return error(tostring(res[2]) .. '\n' .. debug.traceback(self, _, 1), 0)
                        end

                        table.remove(res, 1)
                        
                        return table.unpack(res)
                    end

                    return t[k]
                end
            end,
            __metatable = 'nil'
        })

        -- new math
        setmetatable(new_env.math, {
            __index = function(t, k)
                if (k ~= 'math') then
                    t[k] = function(...)
                        local res = table.pack(pcall(math[k], ...))

                        if (res[1] == false) then
                            return error(tostring(res[2]) .. '\n' .. debug.traceback(self, _, 1), 0)
                        end

                        table.remove(res, 1)
                        
                        return table.unpack(res)
                    end

                    return t[k]
                end
            end,
            __metatable = 'nil'
        })

        -- new os
        setmetatable(new_env.os, {
            __index = function(t, k)
                if (k ~= 'os') then
                    t[k] = function(...)
                        local res = table.pack(pcall(os[k], ...))

                        if (res[1] == false) then
                            return error(tostring(res[2]) .. '\n' .. debug.traceback(self, _, 1), 0)
                        end

                        table.remove(res, 1)
                        
                        return table.unpack(res)
                    end

                    return t[k]
                end
            end,
            __metatable = 'nil'
        })

        -- new string
        setmetatable(new_env.string, {
            __index = function(t, k)
                if (k ~= 'string') then
                    t[k] = function(...)
                        local res = table.pack(pcall(string[k], ...))

                        if (res[1] == false) then
                            return error(tostring(res[2]) .. '\n' .. debug.traceback(self, _, 1), 0)
                        end

                        table.remove(res, 1)
                        
                        return table.unpack(res)
                    end

                    return t[k]
                end
            end,
            __metatable = 'nil'
        })

        -- new table
        setmetatable(new_env.table, {
            __index = function(t, k)
                if (k ~= 'table') then
                    t[k] = function(...)
                        local res = table.pack(pcall(table[k], ...))

                        if (res[1] == false) then
                            return error(tostring(res[2]) .. '\n' .. debug.traceback(self, _, 1), 0)
                        end

                        table.remove(res, 1)
                        
                        return table.unpack(res)
                    end

                    return t[k]
                end
            end,
            __metatable = 'nil'
        })

        -- new utf8
        setmetatable(new_env.utf8, {
            __index = function(t, k)
                if (k ~= 'utf8') then
                    t[k] = function(...)
                        local res = table.pack(pcall(utf8[k], ...))

                        if (res[1] == false) then
                            return error(tostring(res[2]) .. '\n' .. debug.traceback(self, _, 1), 0)
                        end

                        table.remove(res, 1)
                        
                        return table.unpack(res)
                    end

                    return t[k]
                end
            end,
            __metatable = 'nil'
        })

        -- make new require
        setmetatable(new_env.require, {
            __call = function(t, lib_name)
                return require(lib_name)
            end,
            __metatable = 'nil'
        })

        -- make universal form for send requests and events from service to server
        setmetatable(new_env._form, {
            __call = function(t, form, env)
                if (type(form) ~= 'table') then
                    return false, 'incorrect form type!'
                end

                local acl_rule, acl_rule_err = form_handler:validate(form)

                if (not acl_rule) then
                    return false, validate_err
                end

                local access_ok, access_err = form_handler:chk_access(acl_rule)

                if (not access_ok) then
                    return false, access_err
                end

                if (form.target_type == 'signal') then
                    if signal[form.target] then
                        return signal[form.target](env, form)
                    end

                    return false, 'signal not exist'
                end

                if (form.target_type == 'event') then
                    return event[form.target](form)
                end
            end,
            __metatable = 'nil'
        })
        
        -- init
        setmetatable(new_env, {
            __call = function(t)
                return load([=[
                json = require('cjson')

                function get_args()
                    return args
                end

                function load_component(component)
                    return load(component, _, 'bt', _ENV)()
                end

                function load_lang()
                    return load_component(components['lang/' .. config.lang])
                end

                function load_module(target_path)
                    local module, module_err = send_form({
                        target_type = 'signal',
                        target = 'load_module',
                        args = {
                            target_path = tostring(target_path)
                        }
                    })

                    if (not module) then
                        return false, module_err
                    end

                    module()

                    return true
                end

                function route(req_path, args)
                    req_path = req_path or 'default.default'
                    args = args or {}

                    if (type(req_path) == 'string' and type(args) == 'table') then
                        local route_req = json.encode({['req'] = req_path, ['args'] = args})

                        return ']=] .. lserver.config.route_token .. [=[' .. route_req
                    end
                end

                do
                    local MODULE_KEY = ']=] .. modules_keys.core['INIT'] .. [=['
                    local SERVICE_KEY = ']=] .. services_keys[req.package][req.service] .. [=['
                    local PACKAGE = ']=] .. req.package .. [=['
                    local SERVICE = ']=] .. req.service .. [=['
                    local SERVICE_FORM_ADDR = ']=] .. tostring(t._form) .. [=['
                    local idx_proof = {
                        [_form] = MODULE_KEY,
                        [SERVICE_FORM_ADDR] = MODULE_KEY
                    }

                    function send_form(form)
                        if (not idx_proof[tostring(_form)]) then
                            error('_form was modified!', 0)
                        end

                        if (idx_proof[tostring(_form)] ~= MODULE_KEY) then
                            error('_form was modified!', 0)
                        end

                        if (not idx_proof[_form]) then
                            error('_form was modified!', 0)
                        end

                        if (idx_proof[_form] ~= MODULE_KEY) then
                            error('_form was modified!', 0)
                        end

                        if (type(form) ~= 'table') then
                            return false, 'incorrect form type!'
                        end

                        if (not form.module_key) then
                            form.service_key = SERVICE_KEY
                        end

                        form._package = PACKAGE
                        form._service = SERVICE

                        return _form(form, _ENV)
                    end

                    local autoload_modules, autoload_modules_err = send_form({
                        module_key = MODULE_KEY,
                        target_type = 'signal',
                        target = 'get_autoload_modules'
                    })

                    if (not autoload_modules) then
                        error(autoload_modules_err, 0)
                    end
                    
                    local modules_errors = {}

                    for i=1, #autoload_modules do
                        local module, module_err = send_form({
                            module_key = MODULE_KEY,
                            target_type = 'signal',
                            target = 'load_module',
                            args = {
                                target_path = autoload_modules[i]
                            }
                        })

                        if module then
                            module()
                        else
                            table.insert(modules_errors, { ['parameter'] = autoload_modules[i],['error'] = module_err})
                        end
                    end

                    if (#modules_errors > 0) then
                        error(json.encode(modules_errors), 0)
                    end
                end]=], _, 't', t)()
            end,
            __metatable = 'nil'
        })

        return new_env
    end

    function svc.run_service(req, env)
        tasks[1]['tasks'] = tasks[1]['tasks'] + 1
        local service_bc = load(services[req.package][req.service], _, 'bt', env)
        local service_ok, err = pcall(service_bc)

        if (tasks[1]['serial'] == env.service.serial) then
            tasks[1]['tasks'] = tasks[1]['tasks'] - 1
        elseif (tasks[2]['serial'] == env.service.serial) then
            tasks[2]['tasks'] = tasks[2]['tasks'] - 1
        else
            lserver:say('Framework=> Service=> ' .. tostring(req.req) .. ': service serial err!')
        end

        if (tasks[2] and tasks[2]['tasks'] == 0) then
            tasks[2] = nil
            modules_keys2 = nil
            modules_keys_map2 = nil
            services_keys2 = nil
            services_keys_map2 = nil
        end

        if service_ok then
            return tostring(env.service.response)
        end

        if (err == 'handler_mode=1') then
            return tostring(env.service.response)
        end

        lserver:say('Framework=> Service=> ' .. tostring(req.req) .. ': ' .. tostring(err))

        return tostring(err)
    end

    function svc.service_ctl(req_str)
        local f, req = svc.chk_request(req_str)

        if (not f) then
            return req
        end

        if (req.type == 'service') then
            return svc.run_service(req, svc.prepare_env(req))
        end

        if (req.type == 'command') then
            return commands[req.req](req.args)
        end
    end

    -- new
    modules_keys2 = {}
    modules_keys_map2 = {}
    services_keys2 = {}
    services_keys_map2 = {}
    -- new

    init_ok, init_err = lserver:init(args)

    if (not init_ok) then
        error_wrapper:error('init', init_err, {is_critical = true})
    end

    -- create epoll loop
    main_loop = ev.Loop.new(4)

    local server_fd, server_listener = tcp_server(
        lserver.config.host,
        tonumber(lserver.config.port),
        main_loop,
        svc.service_ctl,
        10246
    )

    function stop_tcp_server()
        server_listener:stop(main_loop)
        main_loop:unloop()
        socket.shutdown(server_fd, socket.SHUT_RDWR)
        unistd.close(server_fd)
    end
end

--signal handler on Ctrl+C
sig = ev.Signal.new(
    function(loop, sig)
        sig:stop(loop)
        lserver:normal_exit()
    end,
    posix_signal.SIGINT
)

sig:start(main_loop, true)

-- Start the server
main_loop:loop()