pkg_config = {}
pkg_config.main = {
    -- package name
    name = 'template',
    description = 'My super template project',
    autor = 'Ivanov Ivan',
    year = '2016',
    version = '1.0',
    -- if package not use own database schema, set schema_name = ''
    schema_name = 'template',
    -- preinstall script runs before installing package
    preinstall_script = './scripts/preinstall.lua',
    -- postinstall script runs after installing package
    postinstall_script = './scripts/postinstall.lua',
    -- remove script runs after package remove
    remove_script = './scripts/remove.lua',
    -- separate dependency packages names with ',' char. Example: dependencies = 'auth,hub,users_tool'
    dependencies = '',
    keys_def = ''
    -- keys_def = 'first_key, second_key',
    --                            ^--and this key will be added to main project
    --              ^--this key will be added to main project
    -- install scripts can write values to key store via lib_project:add_key
}

pkg_config.build_script = './scripts/build.lua'

-- package type '1' - standard application, '2' - system package
pkg_config.main.type = '2'

-- if package type is "1"
if (pkg_config.main.type == '1') then
    pkg_config.main.menu_item = {
        ['parent'] = {
            ['en'] = 'Parent category',
            ['ru'] = 'Родительская категория'
        },
        ['category'] = {
            ['en'] = 'New category',
            ['ru'] = 'Новая категория'
        },
        ['item'] = {
            ['en'] = 'New Item',
            ['ru'] = 'Новый пункт меню'
        }
    }
end

-- ['template'] = 'template1'
--     ^--service name ^--service filename without .lua extension
-- main service must be named as pkg_config.main.name
pkg_config.services = {
    ['template'] = 'template1',
}

-- ['template_module'] = 'template_module1'
--       ^--module name       ^--module filename without .lua extension
pkg_config.modules = {
    ['template_module'] = 'template_module1',
    ['main_template_module'] = 'template_module2'
}

pkg_config.autoload_modules = {
    'main_template_module',
}

pkg_config.file_exceptions = {
    ['./' .. pkg_config.main.name .. '.pkg'] = true,
    ['./config.lua'] = true,
    ['./scripts/build.lua'] = true,
    ['./js/src'] = true,
}

pkg_config.luac_exceptions = {
    ['./components/lang'] = true,
    ['./components/schema.sql'] = true,
    ['./man'] = true,
    ['./scripts'] = true,
    ['./js'] = true,
}

-- Access Control List
-- {'source type', 'source', 'target type', 'target'}
--  pkg_config.acl = {
--      {
--          'module', 'hub', 'signal', 'get_key'
--      },
--      {
--          'constant', 'SERVICES', 'constant', 'MODULES'
--      }
--  }
pkg_config.acl = {}

return pkg_config
