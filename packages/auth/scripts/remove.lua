remove = {
    schema_name = 'auth',
    __name = 'remove'
}

res = res or {}

function remove:revoke_priveleges()
    local ok, err = pkg:exec_sql(string.format(
        'REVOKE ALL ON DATABASE "%s" FROM %s, %s;',
        pkg.main_config.db_name,
        pkg.package_config.auth_h_user,
        pkg.package_config.auth_f_user
    ))

    if (not ok) then
        return false, error_wrapper:chain(self, err)
    end

    return true
end

function remove:delete_roles()
    local ok, err = pkg:exec_sql(string.format(
        'DROP ROLE %s, %s;',
        pkg.package_config.auth_h_user,
        pkg.package_config.auth_f_user
    ))

    if (not ok) then
        return false, error_wrapper:chain(self, err)
    end

    return true
end

function remove:run()
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

    dbc:bind(self.schema_name, '')
    res.drop_schema = dbc:drop_schema_cascade(self.schema_name)

    if (res.drop_schema ~= wpgsql.insert_ok) then
        return false, error_wrapper:new(self, 'SQL drop schema error: ' .. tostring(res.drop_schema))
    end

    res.revoke_priveleges, res.revoke_priveleges_err = self:revoke_priveleges()

    if (not res.revoke_priveleges) then
        return false, error_wrapper:chain(self, res.revoke_priveleges_err)
    end

    res.delete_roles, res.delete_roles_err = self:delete_roles()

    if (not res.delete_roles) then
        return false, error_wrapper:chain(self, res.delete_roles_err)
    end

    return true
end

remove_script_ok, remove_script_err = remove:run()

if (not remove_script_ok) then
    return false, error_wrapper:chain(remove, remove_script_err)
end

return remove_script_ok