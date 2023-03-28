package.path = '?;?.lua;/usr/local/share/lua/5.4/?.lua;/usr/local/share/lua/5.4/?/init.lua;/usr/local/lib/lua/5.4/?.lua;/usr/local/lib/lua/5.4/?/init.lua'
package.cpath = '/usr/local/lib/lua/5.4/?.so;/usr/local/lib/lua/5.4/?'

args = {...}

NEF_PATH = require('lib.tools.NEF_PATH')
deepcopy = require('lib.tools.deepcopy')
error_wrapper = require('lib.tools.error_wrapper')
json = require('cjson')
json_file = require('lib.tools.json_file')
lib_auth = require('lib.tools.lib_auth')
lib_file = require('lib.tools.lib_file')
lib_menu = require('lib.tools.lib_menu')
lib_pkg = require('lib.tools.lib_pkg')
lib_project = require('lib.tools.lib_project')
lib_string = require('lib.tools.lib_string')
lib_table = require('lib.tools.lib_table')
pgsql = require('pgsql')
pkg_acl_filter = require('lib.tools.pkg_acl_filter')
pkg_cmd = require('share.pkg_cmd')
pkg_info_msg = require('share.pkg_info_msg')
pkg_statuses = require('share.pkg_statuses')
pretty_json = require('lib.tools.pretty_json')
-- sha2 = require('lib.lsha2')
sqlite = require('lsqlite3complete')
sqlite_ad = require('lib.tools.sqlite_ad')
system_signals = require('share.system_signals')
wpgsql = require('lib.db.wpgsql')

pkg = {
    ['project_name'] = 'main',
    ['package_name'] = false,
    ['target'] = false,
    ['version'] = '1.2 2020',
    ['conn_info_tmpl'] = {
        ['host'] = '',
        ['port'] = '',
        ['user'] = '',
        ['password'] = '',
        ['db_name'] = ''
    },
    ['options'] = {
        ['-p'] = 1,
        ['-d'] = 2,
        ['-a'] = 3,
        ['-t'] = 4,
        ['reinstall'] = 5,
        ['uninstall'] = 6,
        ['build'] = 7,
        ['update'] = 8,
        ['lock'] = 9,
        ['unlock'] = 10,
        ['check'] = 11,
        ['install'] = 12,
        ['checkinstall'] = 13
    },
    ['selected'] = {},
    __name = 'pkg'
}

pkg.options_map = lib_table:map_hash(pkg.options)
dbc = false

function pkg:show_info_msg()
    print(string.format(pkg_info_msg, self.version))
end

function pkg:connect_db(conn_info)
    local errors = {}
    lib_table:compare_by_template(self.conn_info_tmpl, conn_info, errors)

    if (#errors > 0) then
        return false, error_wrapper:new(self, errors)
    end

    if (not dbc) then
        dbc = wpgsql:new()
    end

    for k, v in pairs(conn_info) do
        if (dbc[k] ~= v) then
            dbc:disconnect()
            dbc.sconnection = false

            break
        end
    end

    if (dbc.sconnection and dbc.connection:status() == pgsql.CONNECTION_OK) then
        return true
    end
    
    local conn_ok, conn_err = dbc:connect(
        conn_info.host,
        conn_info.port,
        conn_info.user,
        conn_info.password,
        conn_info.db_name
    )

    if (not conn_ok) then
        return false, error_wrapper:new(self, 'dbc connection error:' .. tostring(conn_err))
    end

    return true
end

function pkg:exec_sql(sql_dump)
    if (type(sql_dump) ~= 'string') then
        return false, error_wrapper:new(self, 'sql_dump must be a string')
    end

    local res = dbc:execute(sql_dump)

    if (res ~= wpgsql.insert_ok) then
        return false, error_wrapper:new(self, 'SQL exec error: ' .. tostring(res))
    end

    return true
end

function pkg:create_schema()
    if (#self.package_config.schema_name < 1) then
        return true
    end

    local schema_dump, schema_dump_err = lib_pkg:get_file(self.pkg_db, './components/' .. self.package_config.schema_name .. '.sql')

    if (not schema_dump) then
        return false, error_wrapper:chain(self, schema_dump_err)
    end

    local connect_db, connect_db_err = self:connect_db({
        ['host'] = self.main_config.db_host,
        ['port'] = self.main_config.db_port,
        ['user'] = self.main_config.db_user,
        ['password'] = self.main_config.db_password,
        ['db_name'] = self.main_config.db_name
    })

    if (not connect_db) then
        return false, error_wrapper:chain(self, connect_db_err)
    end

    local schema_create, schema_create_err = self:exec_sql(schema_dump)

    if (not schema_create) then
        return false, error_wrapper:chain(self, schema_create_err)
    end

    dbc:bind(self.package_config.schema_name, '')
    dbc:cache_update()

    return true
end

function pkg:drop_schema()
    if (#self.package_config.schema_name < 1) then
        return true
    end

    local connect_db, connect_db_err = self:connect_db({
        ['host'] = self.main_config.db_host,
        ['port'] = self.main_config.db_port,
        ['user'] = self.main_config.db_user,
        ['password'] = self.main_config.db_password,
        ['db_name'] = self.main_config.db_name
    })

    if (not connect_db) then
        return false, error_wrapper:chain(self, connect_db_err)
    end

    local schema_drop = dbc:drop_schema_cascade(self.package_config.schema_name)

    if (schema_drop ~= dbc.insert_ok) then
        return false, error_wrapper:new(self, 'SQL drop schema error: ' .. tostring(schema_drop))
    end

    dbc:bind('auth', '')
    dbc:cache_update()

    return true
end

function pkg:run_script(filename, local_mode)
    if local_mode then
        filename = lib_pkg:get_pkg_path(self.package_config.name) .. '/' .. filename

        return dofile(filename)
    end

    local script, script_err = lib_pkg:get_file(self.pkg_db, filename)

    if (not script) then
        return false, error_wrapper:chain(self, script_err, 'no script')
    end

    local script_bc = load(script, _, 't', _ENV)
    local run_ok, run_err = script_bc()

    if (not run_ok) then
        return false, error_wrapper:new(self, run_err)
    end

    return true
end

function pkg:is_in_dependency_chain(pkg_name)
    if (not self.dependency_chain) then
        return false
    end

    local s, f = string.find(self.dependency_chain, pkg_name, 1, true)

    if (s and f) then
        return true
    end

    return false
end

function pkg:add_to_dependency_chain(pkg_name)
    if (not self.dependency_chain) then
        self.dependency_chain = self.package_name
    end

    self.dependency_chain = self.dependency_chain .. ',' .. pkg_name
end

function pkg:install_dependency(main, dep_name, dep_pkg, res)
    local dep_st, dep_st_err = lib_project:chk_install(main, self.project_name, dep_name, dep_pkg)

    if (not dep_st) then
        return false, error_wrapper:chain(self, dep_st_err)
    end

    if (dep_st == 'not installed') then
        res.install_cnt = res.install_cnt + 1
        self:add_to_dependency_chain(dep_name)
        os.execute(string.format(res.install_cmd, self.project_name, dep_name, self.dependency_chain))

        if (res.install_cnt < 3) then
            return self:install_dependency(main, dep_name, dep_pkg, res)
        end

        res.install_cnt = 0

        return false, error_wrapper:new(self, 'Problem with installing package. Install this package manually.')
    end

    local add_dependency_field, add_dependency_field_err = lib_project:add_dependency_field(main, self.package_name, dep_name)

    if (not add_dependency_field) then
        return false, error_wrapper:chain(self, add_dependency_field_err, dep_name)
    end

    if (dep_st == 'installed') then
        return true
    end
    
    if (dep_st == 'locked') then
        local rset_pkg_status, rset_pkg_status_err = lib_project:rset_pkg_status(self.main, self.project_name, self.package_name, 'installed')

        if (not rset_pkg_status) then
            return false, error_wrapper:chain(self, rset_pkg_status_err)
        end
    end

    return true
end

function pkg:install_dependencies(main)
    local errors = {}
    local res = {
        install_cnt = 0,
        install_cmd = string.format(pkg_cmd, NEF_PATH, 'install -d -p %s %s %s')
    }

    if (not self.package_config.dependencies) then
        return false, error_wrapper:new(self, 'dependencies not defined in package config.')
    end

    res.dependencies = lib_string:split(self.package_config.dependencies, ',')

    if (#res.dependencies < 1) then
        return true
    end

    for i=1, #res.dependencies do
        local ctx = {}

        if (not self:is_in_dependency_chain(res.dependencies[i])) then
            ctx.dep_pkg, ctx.dep_pkg_err = lib_pkg:open(res.dependencies[i])

            if (not ctx.dep_pkg) then
                error_wrapper:add(errors, res.dependencies[i], ctx.dep_pkg_err)

                goto continue
            end

            ctx.install_dependency, ctx.install_dependency_err = self:install_dependency(main, res.dependencies[i], ctx.dep_pkg, res)

            if (not ctx.install_dependency) then
                error_wrapper:add(errors, res.dependencies[i], ctx.install_dependency_err)

                goto continue
            end
        end
        
        ::continue::

        if ctx.dep_pkg then
            ctx.dep_pkg:close_vm()
            ctx.dep_pkg:close()
        end
    end

    if (#errors > 0) then
        return false, errors
    end

    return true
end

function pkg:uninstall_dependency(main, dep_name, dep_pkg, res)
    local dep_st, dep_st_err = lib_project:chk_install(main, self.project_name, dep_name, dep_pkg)

    if (not dep_st) then
        return false, error_wrapper:chain(self, dep_st_err)
    end

    if (dep_st == 'not installed') then
        return true
    end

    if (dep_st == 'installed' or dep_st == 'locked') then
        res.uninstall_cnt = res.uninstall_cnt + 1
        self:add_to_dependency_chain(dep_name)
        os.execute(string.format(res.uninstall_cmd, dep_name, self.dependency_chain))

        if (res.uninstall_cnt < 3) then
            return self:uninstall_dependency(main, dep_name, dep_pkg, res)
        end

        res.uninstall_cnt = 0

        return false, error_wrapper:new(self, 'Problem with uninstalling package. Uninstall this package manually.')
    end

    return true
end

function pkg:uninstall_dependencies(main)
    local errors = {}
    local res = {
        uninstall_cnt = 0,
        uninstall_cmd = string.format(pkg_cmd, NEF_PATH, 'uninstall -d %s %s')
    }
    
    if self.all_packages then
        res.uninstall_cmd = string.format(pkg_cmd, NEF_PATH, 'uninstall -a -d %s %s')
    end

    -- if set -a option, pkg.all_packages = 'all'
    res.dependencies, res.dependencies_err = lib_project:get_dependencies(main, self.package_name, self.all_packages or 'ld')

    if (not res.dependencies) then
        return false, error_wrapper:chain(self, res.dependencies_err)
    end

    local dependency_list = ''

    for dep_name, _ in pairs(res.dependencies) do
        dependency_list = dependency_list .. dep_name .. ', '
    end

    dependency_list = string.sub(dependency_list, 1, -3)

    print('Remove following packages:', dependency_list)

    for dep_name, _ in pairs(res.dependencies) do
        local ctx = {}

        if (not self:is_in_dependency_chain(dep_name)) then
            ctx.dep_pkg, ctx.dep_pkg_err = lib_pkg:open(dep_name)

            if (not ctx.dep_pkg) then
                error_wrapper:add(errors, dep_name, ctx.dep_pkg_err)

                goto continue
            end

            ctx.uninstall_dependency, ctx.uninstall_dependency_err = self:uninstall_dependency(main, dep_name, ctx.dep_pkg, res)

            if (not ctx.uninstall_dependency) then
                error_wrapper:add(errors, dep_name, ctx.uninstall_dependency_err)

                goto continue
            end
        end
        
        ::continue::

        if ctx.dep_pkg then
            ctx.dep_pkg:close_vm()
            ctx.dep_pkg:close()
        end
    end

    if (#errors > 0) then
        return false, errors
    end

    return true
end

function pkg:normal_exit()
    if (dbc and dbc.connection:status() == pgsql.CONNECTION_OK) then
        dbc:disconnect()
    end
    
    self.pkg_db:close_vm()
    self.pkg_db:close()
    self.main:close_vm()
    self.main:close()
    
    os.exit()
end

function pkg:init(args)
    if (not args or #args < 2) then
        self:show_info_msg()
        os.exit()
    end

    -- for i=1, lib_table:len(self.options) do
    --     self.selected[i] = 0
    -- end
    for i=1, #self.options_map do
        self.selected[i] = 0
    end

    self.selected_cnt = 0

    for i=1, #args do
        if self.options[args[i]] then
            -- self.selected[self.options[args[i]]] = self.options_map[self.options[args[i]]]
            self.selected[self.options[args[i]]] = self.options[args[i]]
            self.selected_cnt = self.selected_cnt + 1
        end
    end

    self.package_name = args[#args]

    -- Options hooks
    if (self.selected[self.options['reinstall']] == self.options['reinstall'] and self.selected[self.options['build']] == self.options['build']) then 
        self.selected[self.options['build']] = 0
        self.build_after = true
    end

    if (self.selected[self.options['update']] == self.options['update']) then 
        self.package_name = args[#args - 1]
        self.target = args[#args]
    end

    if (self.selected[self.options['-d']] == self.options['-d']) then 
        self.package_name = args[#args - 1]
        self.target = args[#args]
        self.dependency_chain = args[#args]
    end

    if (self.selected[self.options['-p']] == self.options['-p']) then
        self.project_name = args[#args - 1]

        if self.target then
            self.project_name = args[#args - 2]
        end
    end

    if (self.selected[self.options['-a']] == self.options['-a']) then 
        self.all_packages = 'all'
    end

    --run scripts from package source directory
    --also used for testing
    if (self.selected[self.options['-t']] == self.options['-t']) then 
        self.local_mode = true
    end
    -- Options hooks

    if (self.project_name == self.package_name) then
        self:show_info_msg()
        os.exit()
    end

    self.main, self.main_err = lib_project:open_main()

    if (not self.main) then
        error_wrapper:error('lib_project:open_main', self.main_err, {is_critical = true})
    end

    self.projects, self.projects_err = lib_project:get_projects(self.main)

    if (not self.projects) then
        error_wrapper:error('lib_project:get_projects', self.projects_err, {is_critical = true})
    end

    if (self.project_name ~= 'main' and not self.projects[self.project_name]) then
        error_wrapper:error(
            'pkg.projects',
            'Project ' .. self.project_name .. ' not registered in main project',
            {is_critical = true}
        )
    end

    self.main_config, self.main_config_err = lib_project:get_config(self.main, 'main')

    if (not self.main_config) then
        error_wrapper:error('lib_project:get_config', self.main_config_err, {is_critical = true})
    end

    if (self.project_name  == 'main') then
        self.project_config = self.main_config
    else
        self.project_config, self.project_config_err = lib_project:get_config(self.main, self.project_name)

        if (not self.project_config) then
            error_wrapper:error('lib_project:get_config', self.project_config_err, {is_critical = true})
        end
    end

    -- если в pkg.selected нет build, то открываем пакет и берем конфиг
    if (self.selected[self.options['build']] ~= self.options['build']) then
        self.pkg_db, self.pkg_db_err = lib_pkg:open(self.package_name)

        if (not self.pkg_db) then
            error_wrapper:error('lib_pkg:open', self.pkg_db_err, {is_critical = true})
        end

        self.package_config, self.package_config_err = lib_pkg:get_config(self.pkg_db)

        if (not self.package_config) then
            error_wrapper:error('lib_pkg:get_config', self.package_config_err, {is_critical = true})
        end

        if (self.package_config.type == '1') then
            self.package_config.menu_item = json.decode(self.package_config.menu_item)
        end
    end

    if (#args == 0) then
        self:show_info_msg()
    end
end

function pkg:build()
    local res = {}
    res.pkg_path, res.pkg_path_err = lib_pkg:get_pkg_path(self.package_name)
    
    if (not res.pkg_path) then
        return false, error_wrapper:chain(self, res.pkg_path_err)
    end

    res.config_path = res.pkg_path .. '/config.lua'

    if (not lib_file:is_exist(res.config_path)) then
        return false, error_wrapper:new(self, res.config_path .. ' not exist')
    end

    res.build_config = require('packages.' .. self.package_name .. '.config')

    self.pkg_db, res.pkg_db_err = lib_pkg:create(res.build_config)

    if (not self.pkg_db) then
        return false, error_wrapper:chain(self, res.pkg_db_err)
    end

    self.package_config = deepcopy(res.build_config.main)

    -- run build script
    self:run_script(res.build_config.build_script, true)

    res.add_config, res.add_config_err = lib_pkg:add_config(self.pkg_db, res.build_config)

    if (not res.add_config) then
        return false, error_wrapper:chain(self, res.add_config_err)
    end

    res.add_services, res.add_services_err = lib_pkg:add_services(self.pkg_db, res.build_config)

    if (not res.add_services) then
        return false, error_wrapper:chain(self, res.add_services_err)
    end
 
    res.add_modules, res.add_modules_err = lib_pkg:add_modules(self.pkg_db, res.build_config)

    if (not res.add_modules) then
        return false, error_wrapper:chain(self, res.add_modules_err)
    end

    res.add_autoload_modules, res.add_autoload_modules_err = lib_pkg:add_autoload_modules(self.pkg_db, res.build_config)

    if (not res.add_autoload_modules) then
        return false, error_wrapper:chain(self, res.add_autoload_modules_err)
    end

    res.add_acl, res.add_acl_err = lib_pkg:add_acl(self.pkg_db, res.build_config)

    if (not res.add_acl) then
        return false, error_wrapper:chain(self, res.add_acl_err)
    end

    res.add_files, res.add_files_err, res.add_files_dbg = lib_pkg:add_files(self.pkg_db, res.build_config, true)

    if (not res.add_files) then
        return false, error_wrapper:chain(self, res.add_files_err)
    end

    if (self.selected_cnt == 1) then
        -- self.pkg_db:close() --use pkg:normal_exit()
    end

    -- json_file:write(pkg_path .. '/pkg_build_debug.json', res.add_files_dbg)
    print('Build', self.package_name, ': ok')

    return true
end

function pkg:uninstall()
    local res = {}

    -- check install
    res.status, res.status_err, res.status_dbg = lib_project:chk_install(self.main, self.project_name, self.package_name, self.pkg_db, true)

    -- print(res.status_err.error)

    if (res.status and res.status == 'not installed') then
        print('Package not installed.')
    end

    if (not res.status and res.status_err.error ~= 'not found') then
        return false, error_wrapper:chain(self, res.status_err)
    end

    -- check package
    res.pkg_chk, res.pkg_chk_err = lib_pkg:chk(self.pkg_db)

    if (not res.pkg_chk) then
        return false, error_wrapper:chain(self, res.pkg_chk_err)
    end

    -- uninstall dependencies
    res.uninstall_dependencies, res.uninstall_dependencies_err = self:uninstall_dependencies(self.main)

    if (not res.uninstall_dependencies) then
        return false, error_wrapper:chain(self, res.uninstall_dependencies_err)
    end

    -- delete package info
    res.delete_pkg_info, res.delete_pkg_info_err = lib_project:delete_pkg_info(self.main, res.status_dbg.pkg_hash)

    if (not res.delete_pkg_info and res.delete_pkg_info_err.error ~= 'not found') then
        return false, error_wrapper:chain(self, res.delete_pkg_info_err)
    end

    -- remove local files
    res.remove_local_files, res.remove_local_files_err = lib_pkg:remove_local_files(self.pkg_db)

    if (not res.remove_local_files) then
        return false, error_wrapper:chain(self, res.remove_local_files_err)
    end

    -- connect to db
    res.connect_db, res.connect_db_err = self:connect_db({
        ['host'] = self.main_config.db_host,
        ['port'] = self.main_config.db_port,
        ['user'] = self.main_config.db_user,
        ['password'] = self.main_config.db_password,
        ['db_name'] = self.main_config.db_name
    })

    if (not res.connect_db) then
        return false, error_wrapper:chain(self, res.connect_db_err)
    end

    -- delete unit (auth schema)
    res.del_unit = lib_auth:del_unit(dbc, self.package_config.name)

    if (not res.del_unit) then
        return false, error_wrapper:new(self, 'lib_auth:del_unit ==>' .. tostring(res.del_unit))
    end

    -- delete menu item
    if (self.package_config.type == '1') then
        res.iusd_category, res.iusd_category_err = lib_menu:iusd_category(
            dbc,
            self.package_config.menu_item.parent.en,
            self.package_config.menu_item.category.en
        )

        if (not res.iusd_category and not res.iusd_category_err) then
            res.del_category, res.del_category_err = lib_menu:del_category(
                dbc,
                self.package_config.menu_item.parent.en,
                self.package_config.menu_item.category.en
            )

            if (not res.del_category) then
                return false, error_wrapper:chain(self, res.del_category_err)
            end
        elseif (not res.iusd_category and res.iusd_category_err) then
            return false, error_wrapper:chain(self, res.iusd_category_err)
        end
    end

    -- remove script
    res.remove_script, res.remove_script_err = self:run_script(self.package_config.remove_script, self.local_mode)

    if (not res.remove_script) then
        return false, error_wrapper:chain(self, res.remove_script_err)
    end

    -- drop schema
    res.drop_schema, res.drop_schema_err = self:drop_schema()

    if (not res.drop_schema) then
        return false, res.drop_schema_err
    end

    print('Uninstall', self.package_name, ': ok')

    return true
end

function pkg:install()
    local res = {}

    -- check install
    res.status, res.status_err, res.status_dbg = lib_project:chk_install(self.main, self.project_name, self.package_name, self.pkg_db, true)

    -- print(res.status_err.error)

    if res.status then
        if (res.status == 'installed') then
            print('Package ' .. self.package_name .. ' already installed')

            return true
        elseif(res.status == 'locked') then
            print('Package ' .. self.package_name .. ' already installed but locked')

            return true
        end
    end

    if (not res.status and res.status_err.error ~= 'not found') then
        return false, error_wrapper:chain(self, res.status_err)
    end

    -- check package
    res.pkg_chk, res.pkg_chk_err = lib_pkg:chk(self.pkg_db)

    if (not res.pkg_chk) then
        return false, error_wrapper:chain(self, res.pkg_chk_err)
    end

    -- add pkg_info
    res.add_pkg_info, res.add_pkg_info_err = lib_project:add_pkg_info(self.main, {
        self.package_name,
        self.package_config.version,
        res.status_dbg.pkg_hash
    })

    if (not res.add_pkg_info) then
        return false, error_wrapper:chain(self, res.add_pkg_info_err)
    end

    -- dependencies
    res.install_dependencies, res.install_dependencies_err, res.install_dependencies_dbg = self:install_dependencies(self.main, true)

    if (not res.install_dependencies) then
        return false, error_wrapper:chain(self, res.install_dependencies_err)
    end

    -- create schema
    res.create_schema, res.create_schema_err = self:create_schema()

    if (not res.create_schema) then
        return false, res.create_schema_err
    end

    -- preinstall script
    res.preinstall_script, res.preinstall_script_err = self:run_script(self.package_config.preinstall_script, self.local_mode)

    if (not res.preinstall_script) then
        print('no preinstall script')
    
        return false, error_wrapper:chain(self, res.preinstall_script_err)
    end

    -- add autoload modules
    res.add_autoload_modules, res.add_autoload_modules_err = lib_project:add_autoload_modules(self.main, self.project_name, self.pkg_db)

    if (not res.add_autoload_modules) then
        return false, error_wrapper:chain(self, res.add_autoload_modules_err)
    end

    -- add acl
    res.acl_list, res.acl_list_err = lib_pkg:get_acl(self.pkg_db)

    if (not res.acl_list) then
        return false, error_wrapper:chain(self, res.acl_list_err)
    end

    res.add_acl, res.add_acl_err = lib_project:add_acl(self.main, self.project_name, self.pkg_db, res.acl_list)

    if (not res.add_acl) then
        return false, error_wrapper:chain(self, res.add_acl_err)
    end

    -- extract local files
    res.extract_local_files, res.extract_local_files_err = lib_pkg:extract_local_files(self.pkg_db)

    if (not res.extract_local_files) then
        return false, error_wrapper:chain(self, res.extract_local_files_err)
    end

    -- connect to db
    res.connect_db, res.connect_db_err = self:connect_db({
        ['host'] = self.main_config.db_host,
        ['port'] = self.main_config.db_port,
        ['user'] = self.main_config.db_user,
        ['password'] = self.main_config.db_password,
        ['db_name'] = self.main_config.db_name
    })

    if (not res.connect_db) then
        return false, error_wrapper:chain(self, res.connect_db_err)
    end

    -- add unit (auth schema)
    res.exports, res.exports_err = lib_pkg:get_exports(self.pkg_db)

    if (not res.exports) then
        return false, error_wrapper:chain(self, res.exports_err)
    end

    res.exports = json.encode(res.exports)
    res.add_unit = lib_auth:add_unit(dbc, self.package_config.name, res.exports)

    if (not res.add_unit) then
        return false, error_wrapper:new(self, 'lib_auth:add_unit ' .. tostring(res.add_unit))
    end

    -- add policy for admin group
    res.add_policy = lib_auth:add_policy(dbc, 'admin', self.package_config.name, true, true)

    if (not res.add_policy) then
        return false, error_wrapper:new(self, 'lib_auth:add_policy ' .. tostring(res.add_policy))
    end

    -- postinstall script
    res.postinstall_script, res.postinstall_script_err = self:run_script(self.package_config.postinstall_script, self.local_mode)

    if (not res.postinstall_script) then
        return false, error_wrapper:chain(self, res.postinstall_script_err)
    end

    -- add menu item
    if (self.package_config.type == '1') then
        res.add_menu_category, res.add_menu_category_err = lib_menu:add_category(dbc, self.package_config.menu_item)

        if (not res.add_menu_category) then
            return false, error_wrapper:chain(self, res.add_menu_category_err)
        end

        res.add_menu_item, res.add_menu_item_err = lib_menu:add_item(dbc, self.package_config.menu_item, self.package_config.name)

        if (not res.add_menu_item) then
            return false, error_wrapper:chain(self, res.add_menu_item_err)
        end
    end

    -- set package status
    res.set_pkg_status, res.set_pkg_status_err = lib_project:set_pkg_status(self.main, self.project_name, self.package_name, 'installed')

    if (not res.set_pkg_status) then
        return false, error_wrapper:chain(self, res.set_pkg_status_err)
    end

    print('Install', self.package_name, ': ok')

    return true
end

function pkg:update()
    local res = {}
    res.pkg_path, res.pkg_path_err = lib_pkg:get_pkg_path(self.package_name)
    
    if (not res.pkg_path) then
        return false, error_wrapper:chain(self, res.pkg_path_err)
    end

    res.file_path = res.pkg_path .. '/' .. self.target

    if (not lib_file:is_exist(res.file_path)) then
        return false, error_wrapper:new(self, res.file_path .. ' not exist')
    end

    res.config_path = res.pkg_path .. '/config.lua'

    if (not lib_file:is_exist(res.config_path)) then
        return false, error_wrapper:new(self, res.config_path .. ' not exist')
    end

    res.config_file_path_format = './' .. self.target
    res.build_config = require('packages.' .. self.package_name .. '.config')

    for exception, _ in pairs(res.build_config.file_exceptions) do
        local s, e = string.find(res.config_file_path_format, exception, 1, true)

        if (s and e) then
            return false, error_wrapper:new(self, self.target .. ' declared in config.file_exceptions and cannot be included in the package.')
        end
    end

    res.need_compile = true

    for exception, _ in pairs(res.build_config.luac_exceptions) do
        local s, e = string.find(res.config_file_path_format, exception, 1, true)

        if (s and e) then
            res.need_compile = false
        end
    end

    if res.need_compile then
        res.target = luac(res.file_path)

        if (not res.target) then
            return false, error_wrapper:new(self, res.file_path .. ' luac compile error.')
        end
    else
        res.target = lib_file:read(res.file_path)

        if (not res.target) then
            return false, error_wrapper:new(self, res.file_path .. ' reading error.')
        end
    end

    res.add_file, res.add_file_err = lib_pkg:add_file(self.pkg_db, res.config_file_path_format, res.target)

    if (not res.add_file) then
        return false, error_wrapper:chain(self, res.add_file_err)
    end

    return true
end

function pkg:reinstall()
    if self.build_after then
        self.selected[self.options['build']] = self.options['build']
    end

    self.selected[self.options['uninstall']] = self.options['uninstall']
    self.selected[self.options['install']] = self.options['install']

    return true
end

function pkg:lock()
    local lock_pkg, lock_pkg_err = lib_project:set_pkg_status(self.main, self.project_name, self.package_name, 'locked')

    if (not lock_pkg) then
        return false, error_wrapper:chain(self, lock_pkg_err)
    end

    local rlock_packages, rlock_packages_err = lib_project:rset_pkg_status(self.main, self.project_name, self.package_name, 'locked')

    if (not rlock_packages) then
        return false, error_wrapper:chain(self, rlock_packages_err)
    end

    return true
end

function pkg:unlock()
    local unlock_pkg, unlock_pkg_err = lib_project:set_pkg_status(self.main, self.project_name, self.package_name, 'installed')

    if (not unlock_pkg) then
        return false, error_wrapper:chain(self, unlock_pkg_err)
    end

    local runlock_packages, runlock_packages_err = lib_project:rset_pkg_status(self.main, self.project_name, self.package_name, 'installed')

    if (not runlock_packages) then
        return false, error_wrapper:chain(self, runlock_packages_err)
    end

    return true
end

function pkg:check()
    local chk, chk_err = lib_pkg:chk(self.pkg_db)

    if (not chk) then
        return false, error_wrapper:chain(chk_err)
    end

    print('Check package ' .. self.package_name .. ' status: ok')

    return true
end

function pkg:checkinstall()
    local chk, chk_err, chk_dbg = lib_project:chk_install(self.main, self.project_name, self.package_name, self.pkg_db, true)
    local dep_differencies, dep_differencies_err = lib_project:compare_dependency_records(self.main, self.package_name, self.package_config.dependencies)
    -- local dep_differencies, dep_differencies_err = self:compare_dependency_records(self.main)

    if (not chk) then
        if (type(chk_err) == 'string' and pkg_statuses[chk_err]) then
            print('checkinstall status:', chk_err)

            return true
        elseif (type(chk_err) == 'table') then
            return false, error_wrapper:chain(self, chk_err)
        end

        -- json_file:write(NEF_PATH .. '/' .. self.package_name .. '_dbg.json', chk_dbg)

        return
    end

    if (({['installed'] = true, ['locked'] = true})[chk] and dep_differencies_err) then
        print(string.format('Package %s status: %s, but additional dependencies need to be install. ', self.package_name, chk))

        return false, error_wrapper:new(self, dep_differencies_err)
    end

    print(string.format('Package %s status: %s', self.package_name, chk))

    return true
end

-----------------------------------------
--               INIT                  --
-----------------------------------------
pkg:init(args)

for i=1, #pkg.selected do
    if (pkg.selected[i] > 0) then
        local option = pkg.options_map[pkg.selected[i]]

        if (#option > 2) then
            local ok, err = pkg[option](pkg)

            if (not ok) then
                error_wrapper:error(pkg, err, {is_critical = true})
            end
        end
    end
end

pkg:normal_exit()