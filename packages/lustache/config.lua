local pkg_config = {
    main = {
        --package name
        name = 'lustache',
        description = 'Lua mustache template parsing.',
        autor = 'Olivine Labs, LLC <projects@olivinelabs.com>\nEdited by Senin Stanislav for NEF Framework 2015',
        year = '2013',
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

--package type '1' - standard application, '2' - system package
pkg_config.main.type = '2'

--if package type is "1"
if (pkg_config.main.type == '1') then
    pkg_config.main.menu_item = 'parent_category.new_category.new_item'
    --new_category must be defined in lang files!------^
    --new_item must be defined in lang files!--------------------^
    --do not define parent_category because this category already declared
end

--['template'] = 'template1'
--    ^--service name ^--service filename without .lua extension
--main service must be named as pkg_config.main.name
pkg_config.services = {
    ['lustache'] = 'lustache',
}

--['template_module'] = 'template_module1'
--      ^--module name       ^--module filename without .lua extension
pkg_config.modules = {}
--
pkg_config.autoload_modules = {}

pkg_config.file_exceptions = {
    ['./' .. pkg_config.main.name .. '.pkg'] = true,
    ['./config.lua'] = true,
    ['./dw.list'] = true,
}

pkg_config.luac_exceptions = {
    ['./man'] = true,
    ['./scripts'] = true
}

--Access Control List
--{'source type', 'source', 'target type', 'target'}
-- pkg_config.acl = {
--     {
--         'module', 'hub', 'signal', 'INREQ'
--     },
--     {
--         'constant', 'SERVICES', 'constant', 'MODULES'
--     }
-- }
pkg_config.acl = {}

return pkg_config