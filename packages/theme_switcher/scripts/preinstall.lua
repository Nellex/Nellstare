preinstall = {
    light_theme = 'lara-light-indigo',
    dark_theme = 'vela-green',
    __name = 'preinstall'
}

function preinstall:run()
    local res = {}

    res.dark_theme_add, res.dark_theme_add_err = lib_project:add_key(pkg.main, pkg.package_name, 'dark_theme', self.dark_theme)

    if (not res.dark_theme_add) then
        return false, error_wrapper:chain(self, res.dark_theme_add_err)
    end

    res.light_theme_add, res.light_theme_add_err = lib_project:add_key(pkg.main, pkg.package_name, 'light_theme', self.light_theme)

    if (not res.light_theme_add) then
        return false, error_wrapper:chain(self, res.light_theme_add_err)
    end

    return true
end

preinstall_script_ok, preinstall_script_err = preinstall:run()

if (not preinstall_script_ok) then
    return false, error_wrapper:chain(preinstall, preinstall_script_err)
end

return preinstall_script_ok