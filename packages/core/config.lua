local pkg_config = {
    main = {
        --package name
        name = 'core',
        description = 'Virtual package for framework needs',
        autor = 'Senin Stanislav',
        year = '2020',
        version = '1.0',
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
        keys_def = ''
        --keys_def = 'first_key, second_key',
        --                            ^--and this key will be added to main project
        --              ^--this key will be added to main project
        --install scripts can write values to key store via lib_project:add_key
    }
}

pkg_config.build_script = './scripts/build.lua'

--package type '1' - standard application, '2' - system package
pkg_config.main.type = '2'

--['template'] = 'template1'
--    ^--service name ^--service filename without .lua extension
--main service must be named as pkg_config.main.name
pkg_config.services = {
    ['core'] = 'core',
}

--['template_module'] = 'template_module1'
--      ^--module name       ^--module filename without .lua extension
pkg_config.modules = {
    ['INIT'] = 'INIT'
}
--
pkg_config.autoload_modules = {}

pkg_config.file_exceptions = {
    ['./' .. pkg_config.main.name .. '.pkg'] = true,
    ['./config.lua'] = true,
    ['./dw.list'] = true,
}

pkg_config.luac_exceptions = {
    ['./components/lang'] = true,
    ['./scripts'] = true
}

pkg_config.acl = {
    {'module', 'INIT', 'constant', 'MODULES'},
    {'module', 'INIT', 'constant', 'SIGNALS'}
}

return pkg_config
