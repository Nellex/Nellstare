do
    local MODULE_KEY = '${module_key}'

    packages_list, packages_list_err = send_form({
        module_key = MODULE_KEY,
        target_type = 'signal',
        target = 'get_packages_list'
    })

    if (not packages_list) then
        error(packages_list_err, 0)
    end
end