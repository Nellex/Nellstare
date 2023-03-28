_ENV()
m_auth_run('hub')

base64 = require('lib.base64')
base64.alpha('base64url')

local args = get_args()

if (args.meth == 'get_menu_data') then
    load_component(components['model/menu'])

    local res, err = menu:get_data()
    local response

    if (not res) then
        response = {
            ['jsonData'] = {
                ['error'] = err
            }
        }
    else
        response = {
            ['jsonData'] = {
                ['categories'] = res[1],
                ['items'] = res[2],
                ['units'] = res[3]
            }
        }
    end

    service.response = json.encode(response)
    
    return
end

service.response = json.encode({
    ['js'] = string.format('%s/%s/app.js', config.js_url, service.package_name)
})