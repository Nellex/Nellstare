do
    local MODULE_KEY = '${module_key}'

    auth_f_user, auth_f_user_err = send_form({
        module_key = MODULE_KEY,
        target_type = 'signal',
        target = 'get_key',
        args = {
            key = 'auth_f_user'
        }
    })

    if (not auth_f_user) then
        error(auth_f_user_err, 0)
    end

    auth_f_passwd, auth_f_passwd_err = send_form({
        module_key = MODULE_KEY,
        target_type = 'signal',
        target = 'get_key',
        args = {
            key = 'auth_f_passwd'
        }
    })

    if (not auth_f_passwd) then
        error(auth_f_passwd_err, 0)
    end

    secret1, secret1_err = send_form({
        module_key = MODULE_KEY,
        target_type = 'signal',
        target = 'get_key',
        args = {
            key = 'secret1'
        }
    })

    if (not secret1) then
        error(secret1_err, 0)
    end

    secret2, secret2_err = send_form({
        module_key = MODULE_KEY,
        target_type = 'signal',
        target = 'get_key',
        args = {
            key = 'secret2'
        }
    })

    if (not secret2) then
        error(secret2_err, 0)
    end
end