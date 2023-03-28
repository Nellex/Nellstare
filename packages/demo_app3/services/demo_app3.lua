_ENV()
m_auth_run('demo_app3')

base64 = require('lib.base64'); base64.alpha("base64url")
local args = get_args()

response = {
    ['js'] = string.format('%s/%s/standalone.js', config.js_url, service.package_name)
}

if (args.meth and args.meth == 'launch') then
    response = {
        ['url'] = string.format('%s/%s/launcher.js', config.js_url, service.package_name)
    }
end

if (args.meth and args.meth == 'say') then
    service.cache.hello_cnt = (service.cache.hello_cnt or 0) + 1
    save_cache()

    response = {
        ['encodedData'] = base64.encode('Hello from Demo application 3! Message #' .. tostring(service.cache.hello_cnt))
    }
end

service.response = json.encode(response)