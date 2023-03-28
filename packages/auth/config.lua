local pkg_config = {
    main = {
        --package name
        name = 'auth',
        description = 'Authentification package',
        autor = 'Senin Stanislav',
        year = '2020',
        version = '1.1',
        --if package not use own database schema, set schema_name = ''
        schema_name = '',
        --preinstall script runs before installing package
        preinstall_script = './scripts/preinstall.lua',
        --postinstall script runs after installing package
        postinstall_script = './scripts/postinstall.lua',
        --remove script runs after package remove
        remove_script = './scripts/remove.lua',
        --separate dependency packages names with ',' char. Example: dependencies = 'auth,hub,users_tool'
        dependencies = '',
        keys_def = '',
        --keys_def = 'first_key, second_key',
        --                            ^--and this key will be added to main project
        --              ^--this key will be added to main project
        --install scripts can write values to key store via lib_project:add_key
        auth_h_user = 'auth_h',
        auth_f_user = 'auth_f'
    }
}

pkg_config.build_script = './scripts/build.lua'

--package type '1' - standard application, '2' - system package
pkg_config.main.type = '2'

--['template'] = 'template1'
--    ^--service name ^--service filename without .lua extension
--main service must be named as pkg_config.main.name
pkg_config.services = {
    ['auth'] = 's_auth',
}

--['template_module'] = 'template_module1'
--      ^--module name       ^--module filename without .lua extension
pkg_config.modules = {
    ['m_auth'] = 'm_auth',
    ['vars'] = 'vars'
}
--
pkg_config.autoload_modules = {
    'm_auth',
}

pkg_config.file_exceptions = {
    ['./' .. pkg_config.main.name .. '.pkg'] = true,
    ['./config.lua'] = true,
    ['./dw.list'] = true,
}

pkg_config.luac_exceptions = {
    ['./components/auth.sql'] = true,
    ['./man'] = true,
    ['./scripts'] = true
}

pkg_config.acl = {
    {'module', 'm_auth', 'signal', 'get_key'},
    {'module', 'm_auth', 'signal', 'get_cache'},
    {'module', 'm_auth', 'signal', 'save_cache'},
    {'module', 'vars', 'signal', 'get_key'},
    {'service', 'auth', 'module', 'auth.vars'}
}

return pkg_config
