_ENV()

local vars_st, vars_st_err = load_module('auth.vars')

if (not vars_st) then
    error(vars_st_err, 0)
end

bcrypt = require('bcrypt')
gp = require('lib.tools.gp')
hmac = require('openssl.hmac')
lib_auth = require('lib.tools.lib_auth')
lib_string = require('lib.tools.lib_string')
wpgsql = require('lib.db.wpgsql')

base64 = require('lib.base64') ;base64.alpha("base64url")
auth_db = wpgsql:new()

function err_permission(meth_name)
    return string.format('%s.%s=> %s: permission denied! User id: %s', service.package_name, service.name, meth_name, id())
end

auth = {
    __name = 'auth'
}

function auth:renew_tokens()
    return lib_auth:renew_tokens(auth_db, args.token, args.ticket, secret1, secret2, config.session_lifetime, config.refresh_lifetime)
end

function auth:login()
    return lib_auth:login(auth_db, args.usr, args.passwd, secret1, secret2, config.session_lifetime, config.refresh_lifetime)
end

function auth:logout()
    return lib_auth:logout(auth_db, id())
end

function auth:chk_usr()
    if (not get_pol()) then
        return err_permission('chk_usr')
    end

    return lib_auth:chk_usr(auth_db, args.usr)
end

function auth:add_usr()
    if (not get_pol('rw')) then
        return err_permission('add_usr')
    end

    return lib_auth:add_usr(auth_db, args.usr, args.passwd, config.bcrypt_rounds)
end

function auth:del_usr()
    if (not get_pol('rw')) then
        return err_permission('del_usr')
    end

    return lib_auth:del_usr(auth_db, args.usr)
end

function auth:rename_usr()
    if (not get_pol('rw')) then
        return err_permission('rename_usr')
    end

    return lib_auth:rename_usr(auth_db, args.usr, args.new_usr)
end

function auth:chpasswd_usr()
    if (not get_pol('rw')) then
        return err_permission('chpasswd_usr')
    end

    return lib_auth:chpasswd_usr(auth_db, args.usr, args.new_passwd, config.bcrypt_rounds)
end

function auth:get_usrs()
    if (not get_pol()) then
        return err_permission('get_usrs')
    end

    return lib_auth:get_usrs(auth_db)
end

function auth:chk_grp()
    if (not get_pol()) then
        return err_permission('chk_grp')
    end

    return lib_auth:chk_grp(auth_db, args.grp)
end

function auth:add_grp()
    if (not get_pol('rw')) then
        return err_permission('add_grp')
    end

    return lib_auth:add_grp(auth_db, args.grp, args.description)
end

function auth:del_grp()
    if (not get_pol('rw')) then
        return err_permission('del_grp')
    end

    return lib_auth:del_grp(auth_db, args.grp)
end

function auth:rename_grp()
    if (not get_pol('rw')) then
        return err_permission('rename_grp')
    end

    return lib_auth:rename_grp(auth_db, args.grp, args.new_grp, args.description)
end

function auth:get_grps()
    if (not get_pol()) then
        return err_permission('get_grps')
    end

    return lib_auth:get_grps(auth_db)
end

function auth:chk_usr_grp()
    if (not get_pol()) then
        return err_permission('chk_usr_grp')
    end

    return lib_auth:chk_usr_grp(auth_db, args.usr, args.grp)
end

function auth:add_usr_grp()
    if (not get_pol('rw')) then
        return err_permission('add_usr_grp')
    end

    return lib_auth:add_usr_grp(auth_db, args.usr, args.grp)
end

function auth:del_usr_grp()
    if (not get_pol('rw')) then
        return err_permission('del_usr_grp')
    end

    return lib_auth:del_usr_grp(auth_db, args.usr, args.grp)
end

function auth:get_usrs_grps()
    if (not get_pol()) then
        return err_permission('get_usrs_grps')
    end

    return lib_auth:get_usrs_grps(auth_db)
end

function auth:get_usrs_grps2()
    if (not get_pol()) then
        return err_permission('get_usrs_grps2')
    end

    return lib_auth:get_usrs_grps2(auth_db)
end

function auth:get_usrs_wt_grps()
    if (not get_pol()) then
        return err_permission('get_usrs_wt_grps')
    end

    return lib_auth:get_usrs_wt_grps(auth_db)
end

function auth:chk_unit()
    if (not get_pol()) then
        return err_permission('chk_unit')
    end

    return lib_auth:chk_unit(auth_db, args.unit)
end

function auth:add_unit()
    if (not get_pol('rw')) then
        return err_permission('add_unit')
    end

    return lib_auth:add_unit(auth_db, args.unit, args.exports)
end

function auth:del_unit()
    if (not get_pol('rw')) then
        return err_permission('del_unit')
    end

    return lib_auth:del_unit(auth_db, args.unit)
end

function auth:get_units()
    if (not get_pol()) then
        return err_permission('get_units')
    end

    return lib_auth:get_units(auth_db)
end

function auth:chk_policy()
    if (not get_pol()) then
        return err_permission('chk_policy')
    end

    return lib_auth:chk_policy(auth_db, args.grp, args.unit)
end

function auth:add_policy()
    if (not get_pol('rw')) then
        return err_permission('add_policy')
    end

    return lib_auth:add_policy(auth_db, args.grp, args.unit, args.r_p, args.w_p)
end

function auth:del_policy()
    if (not get_pol('rw')) then
        return err_permission('del_policy')
    end

    return lib_auth:del_policy(auth_db, args.grp, args.unit)
end

function auth:update_policy()
    if (not get_pol('rw')) then
        return err_permission('update_policy')
    end

    return lib_auth:update_policy(auth_db, args.grp, args.unit, args.r_p, args.w_p)
end

function auth:get_policies()
    if (not get_pol()) then
        return err_permission('get_policies')
    end

    return lib_auth:get_policies(auth_db, args.unit)
end

function auth:get_grp_policies()
    if (not get_pol()) then
        return err_permission('get_grp_policies')
    end

    return lib_auth:get_grp_policies(auth_db, args.grp)
end

if (not auth[args.meth]) then
    error('Service=> Auth=> method: ' .. tostring(args.meth) .. ' not exist!', 0)
end

local connect_ok, connect_err = auth_db:connect(config.db_host, config.db_port, auth_f_user, auth_f_passwd, config.db_name)

if (not connect_ok) then
    error('Service=> Auth=> ' .. connect_err, 0)
end

if (not ({login = true, renew_tokens = true})[args.meth]) then
    m_auth_run('auth')
end

response = auth[args.meth](auth)

if (type(response) == 'string') then
    service.response = json.encode({
        encodedData = base64.encode(response)
    })
end

if (type(response) == 'boolean' or type(response) == 'number') then
    service.response = tostring(response)
end

if (type(response) == 'table') then
    service.response = json.encode({
        jsonData = response
    })
end

auth_db:disconnect()