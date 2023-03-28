_ENV()

service.response = json.encode(
    {
        ['js'] = string.format('%s/%s/login.js', config.js_url, service.package_name)
    }
)