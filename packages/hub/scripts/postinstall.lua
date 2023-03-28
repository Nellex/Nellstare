root_categories = require('share.root_categories')

postinstall = {
    __name = 'postinstall'
}

function postinstall:run()
    local res = {}

    res.connect_db, res.connect_db_err = pkg:connect_db({
        ['host'] = pkg.main_config.db_host,
        ['port'] = pkg.main_config.db_port,
        ['user'] = pkg.main_config.db_user,
        ['password'] = pkg.main_config.db_password,
        ['db_name'] = pkg.main_config.db_name
    })

    if (not res.connect_db) then
        return false, error_wrapper:chain(self, res.connect_db_err)
    end

    dbc:bind(pkg.package_config.schema_name, '')
    dbc:cache_update()

    local errors = {}

    for i=1, #root_categories do
        local res, err = lib_menu:add_category(dbc, root_categories[i])

        if (not res) then
            error_wrapper:add(errors, root_categories[i]['category']['en'], err)
        end
    end

    if (#errors > 0) then
        return false, error_wrapper:new(self, errors)
    end

    print('Add categories: ok')

    return true
end

postinstall_script_ok, postinstall_script_err = postinstall:run()

if (not postinstall_script_ok) then
    return false, error_wrapper:chain(postinstall, postinstall_script_err)
end

return postinstall_script_ok