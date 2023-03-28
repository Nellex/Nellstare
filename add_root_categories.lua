error_wrapper = require('lib.tools.error_wrapper')
wpgsql = require('lib.db.wpgsql')
lib_project = require('lib.tools.lib_project')
lib_menu = require('lib.tools.lib_menu')

root_categories = require('share.root_categories')

menu_cat = {
    __name = 'menu_cat'
}

function menu_cat:connect_db(conn_info)
    dbc = wpgsql:new()

    local conn_ok, conn_err = dbc:connect(
        conn_info.host,
        conn_info.port,
        conn_info.user,
        conn_info.password,
        conn_info.db_name
    )

    if (not conn_ok) then
        return false, error_wrapper:new(self, 'dbc connection error: ' .. tostring(conn_err))
    end

    if (dbc.sconnection and dbc.connection:status() == pgsql.CONNECTION_OK) then
        return true
    end

    return false, error_wrapper:new(self,  'dbc connection error: ' .. tostring(dbc.connection:status()))
end

menu_cat.main, menu_cat.main_err = lib_project:open_main()

if (not menu_cat.main) then
    error_wrapper:error('lib_project:open_main', menu_cat.main_err, {is_critical = true})
end

menu_cat.main_config, menu_cat.main_config_err = lib_project:get_config(menu_cat.main, 'main')

if (not menu_cat.main_config) then
    error_wrapper:error('lib_project:get_config', menu_cat.main_config_err, {is_critical = true})
end

menu_categories, menu_categories_err = menu_cat:connect_db({
    ['host'] = menu_cat.main_config.db_host,
    ['port'] = menu_cat.main_config.db_port,
    ['user'] = menu_cat.main_config.db_user,
    ['password'] = menu_cat.main_config.db_password,
    ['db_name'] = menu_cat.main_config.db_name
})

if (not menu_categories) then
    error_wrapper:error('menu_cat:connect_db', menu_categories_err, {is_critical = true})
end

local errors = {}

for i=1, #root_categories do
    local res, err = lib_menu:add_category(dbc, root_categories[i])

    if (not res) then
        error_wrapper:add(errors, root_categories[i]['category']['en'], err)
    end
end

if (#errors > 0) then
    error_wrapper:error('Add categories errors:', errors, {is_critical = true})
end

print('Add categories: ok')