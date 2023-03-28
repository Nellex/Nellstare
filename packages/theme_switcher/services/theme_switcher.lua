_ENV()

local args = get_args()
local response = {}

if (args.meth == 'get_themes') then
    local vars_st, vars_st_err = load_module('theme_switcher.vars')

    if (not vars_st) then
        error(vars_st_err, 0)
    end

    response.jsonData = {
        ['dark'] = string.format('%s/themes/%s/theme.css', config.css_url, dark_theme),
        ['light'] = string.format('%s/themes/%s/theme.css', config.css_url, light_theme),
    }
end

if (args.meth == 'launch') then
    response.url = string.format('%s/%s/launcher.js', config.js_url, service.package_name)
end

service.response = json.encode(response)