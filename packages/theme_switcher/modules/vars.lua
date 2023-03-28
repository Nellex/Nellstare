do
    local MODULE_KEY = '${module_key}'

    light_theme, light_theme_err = send_form({
        module_key = MODULE_KEY,
        target_type = 'signal',
        target = 'get_key',
        args = {
            key = 'light_theme'
        }
    })

    if (not light_theme) then
        error(light_theme_err, 0)
    end

    dark_theme, dark_theme_err = send_form({
        module_key = MODULE_KEY,
        target_type = 'signal',
        target = 'get_key',
        args = {
            key = 'dark_theme'
        }
    })

    if (not dark_theme) then
        error(dark_theme_err, 0)
    end
end