bcrypt = require('bcrypt')
gp = require('lib.tools.gp')
iopasswd = require('lib.iopasswd')
lib_string = require('lib.tools.lib_string')

res = {}

preinstall = {
    schema_name = 'auth',
    schema_path = './components/auth.sql',
    tables = {
        'users',
        'groups',
        'units',
        'users_groups',
        'sessions',
        'groups_policies',
        'users_in_groups',
        'users_without_groups'
    },
    tables_list = '',
    __name = 'preinstall'
}

function preinstall:tables_to_list()
    self.tables_list = string.rep(self.schema_name .. '.%s', #self.tables, ', ')
    self.tables_list = string.format(self.tables_list, table.unpack(self.tables))
end

function preinstall:get_sql_dump(dump_path)
    local sql_dump, sql_dump_err = lib_pkg:get_file(pkg.pkg_db, dump_path)

    if (not sql_dump) then
        return false, error_wrapper:chain(self, sql_dump_err)
    end

    return sql_dump
end

function preinstall:create_json_cast()
    local cnt = 0

    repeat
        local postgres_passwd = iopasswd:enter_passwd('Enter your postgres password for create json cast: ', '•', 250)
        local connect_db, connect_db_err = pkg:connect_db({
            ['host'] = pkg.main_config.db_host,
            ['port'] = pkg.main_config.db_port,
            ['user'] = 'postgres',
            ['password'] = postgres_passwd,
            ['db_name'] = pkg.main_config.db_name
        })

        cnt = cnt + 1

        if (cnt > 4) then
            print('Try entering postgres password later')

            break
        end
    until connect_db

    local create_json_cast_st = dbc:create_text_to_json_cast()
    dbc:disconnect()

    if (create_json_cast_st ~= wpgsql.insert_ok) then
        return false, error_wrapper:new(self, 'SQL execution error: ' .. tostring(create_json_cast_st))
    end

    return true
end

function preinstall:create_roles()
    local auth_h_passwd = gp:generate(16)
    local auth_f_passwd = gp:generate(16)

    res.roles_sql_exec, res.roles_sql_exec_err = pkg:exec_sql(string.format(
        [[BEGIN;
        CREATE ROLE %s ENCRYPTED PASSWORD '%s'
        LOGIN NOSUPERUSER NOINHERIT NOCREATEDB NOCREATEROLE NOREPLICATION;
        CREATE ROLE %s ENCRYPTED PASSWORD '%s'
        LOGIN NOSUPERUSER NOINHERIT NOCREATEDB NOCREATEROLE NOREPLICATION;
        COMMIT;]],
        pkg.package_config.auth_h_user,
        auth_h_passwd,
        pkg.package_config.auth_f_user,
        auth_f_passwd
    ))

    if (not res.roles_sql_exec) then
        return false, error_wrapper:chain(self, res.roles_sql_exec_err)
    end

    res.auth_h_user_key_add, res.auth_h_user_key_add_err = lib_project:add_key(pkg.main, pkg.package_name, 'auth_h_user', pkg.package_config.auth_h_user)

    if (not res.auth_h_user_key_add) then
        return false, error_wrapper:chain(self, res.auth_h_user_key_add_err)
    end

    res.auth_h_passwd_add, res.auth_h_passwd_add_err = lib_project:add_key(pkg.main, pkg.package_name, 'auth_h_passwd', auth_h_passwd)
    
    if (not res.auth_h_passwd_add) then
        return false, error_wrapper:chain(self, res.auth_h_passwd_add_err)
    end

    res.auth_f_user_key_add, res.auth_f_user_key_add_err = lib_project:add_key(pkg.main, pkg.package_name, 'auth_f_user', pkg.package_config.auth_f_user)

    if (not res.auth_f_user_key_add) then
        return false, error_wrapper:chain(self, res.auth_f_user_key_add_err)
    end

    res.auth_f_passwd_add, res.auth_f_passwd_add_err = lib_project:add_key(pkg.main, pkg.package_name, 'auth_f_passwd', auth_f_passwd)

    if (not res.auth_f_passwd_add) then
        return false, error_wrapper:chain(self, res.auth_f_passwd_add_err)
    end

    return true
end

function preinstall:grant_priveleges()
    res.priveleges_sql_exec, res.priveleges_sql_exec_err = pkg:exec_sql(string.format(
        [[BEGIN;
        GRANT CONNECT ON DATABASE "%s" TO %s, %s;
        GRANT USAGE ON SCHEMA %s TO %s, %s;
        GRANT SELECT ON TABLE %s TO %s;
        GRANT ALL ON TABLE %s TO %s;
        GRANT SELECT ON ALL SEQUENCES IN SCHEMA %s TO %s;
        GRANT ALL ON ALL SEQUENCES IN SCHEMA %s TO %s;
        COMMIT;]],
        pkg.main_config.db_name,
        pkg.package_config.auth_h_user,
        pkg.package_config.auth_f_user,
        self.schema_name,
        pkg.package_config.auth_h_user,
        pkg.package_config.auth_f_user,
        self.tables_list,
        pkg.package_config.auth_h_user,
        self.tables_list,
        pkg.package_config.auth_f_user,
        self.schema_name,
        pkg.package_config.auth_h_user,
        self.schema_name,
        pkg.package_config.auth_f_user
    ))

    if (not res.priveleges_sql_exec) then
        return false, error_wrapper:chain(self, res.priveleges_sql_exec_err)
    end

    return true
end

function preinstall:add_secrets()
    res.add_secret1, res.add_secret1_err = lib_project:add_key(pkg.main, pkg.package_name, 'secret1', gp:generate(16))
    res.add_secret2, res.add_secret2_err = lib_project:add_key(pkg.main, pkg.package_name, 'secret2', gp:generate(16))

    if (not res.add_secret1) then
        return false, error_wrapper:new(self, res.add_secret1_err)
    end

    if (not res.add_secret2) then
        return false, error_wrapper:new(self, res.add_secret2_err)
    end

    return true
end

function preinstall:run()
    res.json_cast, res.json_cast_err = self:create_json_cast()

    if (not res.json_cast) then
        return false, error_wrapper:chain(self, res.json_cast_err)
    end

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

    res.schema_dump, res.schema_dump_err = self:get_sql_dump(self.schema_path)

    if (not res.schema_dump) then
        return false, error_wrapper:chain(self, res.schema_dump_err)
    end

    res.create_roles, res.create_roles_err = self:create_roles()

    if (not res.create_roles) then
        return false, error_wrapper:chain(self, res.create_roles_err)
    end

    res.schema_dump = lib_string:replace(
        res.schema_dump,
        {
            ['owner'] = pkg.main_config.db_user
        }
    )

    res.restore_schema, res.restore_schema_err = pkg:exec_sql(res.schema_dump)

    if (not res.restore_schema) then
        return false, error_wrapper:chain(self, res.restore_schema_err)
    end

    dbc:bind(self.schema_name, '')
    dbc:cache_update()

    res.add_secrets, res.add_secrets_err = self:add_secrets()

    if (not res.add_secrets) then
        return false, error_wrapper:chain(self, res.add_secrets_err)
    end

    res.grant_priveleges, res.grant_priveleges_err = self:grant_priveleges()

    if (not res.grant_priveleges) then
        return false, error_wrapper:chain(self, res.grant_priveleges_err)
    end

    res.add_admin = lib_auth:add_usr(dbc, 'admin', 'admin', pkg.main_config.bcrypt_rounds)

    if (not res.add_admin) then
        return false, error_wrapper:new(self, 'error with adding admin user')
    end

    res.add_admin_group = lib_auth:add_grp(dbc, 'admin', "''")

    if (not res.add_admin_group) then
        return false, error_wrapper:new(self, 'error with adding admin group')
    end

    res.add_admin_usr_to_admin_grp = lib_auth:add_usr_grp(dbc, 'admin', 'admin')

    if (not res.add_admin_usr_to_admin_grp) then
        return false, error_wrapper:new(self, 'error with adding admin user to admin group')
    end

    return true
end

preinstall:tables_to_list()
preinstall_script_ok, preinstall_script_err = preinstall:run()

if (not preinstall_script_ok) then
    return false, error_wrapper:chain(preinstall, preinstall_script_err)
    -- return error_wrapper:chain(preinstall, preinstall_script_err)
end

return preinstall_script_ok