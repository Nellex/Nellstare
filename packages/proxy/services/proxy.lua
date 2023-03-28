_ENV()

base64 = require('lib.base64') ;base64.alpha("base64url")
lib_string = require('lib.tools.lib_string')

local args = get_args()

proxy_req_js = '/proxyReq.js'

if args.reverse_route then
    service.response = lib_string:replace(components['view/proxy.html'], {
        title = 'Nellstare proxy page',
        lang = config.lang,
        js_url = config.js_url,
        css_url = config.css_url,
        nef_js = '/nef-next.js',
        base64_js = '/base64.js',
        react_js = '/react.production.min.js',
        react_dom_js = '/react-dom.production.min.js',
        react_transition_group_js = '/react-transition-group.js',
        primereact_js = '/primereact.all.min.js',
        proxy_req_js = proxy_req_js,
        primeicons = '/primeicons.css',
        blueprintjs_icons = '/bpicons.css',
        primereact_css = '/primereact.min.css',
        primeflex = '/primeflex.min.css',
        prime_theme = '/themes/vela-green/theme.css',
        package_name = service.package_name,
        scontroller_url = config.scontroller_url,
        reverse_route = args.reverse_route
    })

    return
end

if (args.meth == 'proxy_req_js') then
    service.response = json.encode({
        ['url'] = string.format('%s/%s%s', config.js_url, service.package_name, proxy_req_js)
    })

    return
end

if (args.meth == 'chk_token') then
    m_auth_run('auth', true)

    service.response = json.encode({
        ['encodedData'] = base64.encode('true')
    })

    return
end

service.response = '<h1>No reverse_route!</h1>'