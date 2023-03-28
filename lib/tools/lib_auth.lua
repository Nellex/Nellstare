local base64 = require('lib.base64'); base64.alpha("base64url")
local bcrypt = require('bcrypt')
local gp = require('lib.tools.gp')
local hmac = require('openssl.hmac')
local json = require('cjson')
local lib_string = require('lib.tools.lib_string')
local wpgsql = require('lib.db.wpgsql')

local lib_auth = {}

function lib_auth:new_token(usr_id, secret1, secret2, session_lifetime, refresh_lifetime)
    local a_hmac = hmac.new(secret1, 'sha512')
    local r_hmac = hmac.new(secret2, 'sha512')
    local now = os.time()
    local a_exp = now + session_lifetime * 60
    local r_exp = now + refresh_lifetime * 86400
    local v_code1 = gp:generate(10)
    local v_code2 = gp:generate(10)

    local a_payload = {
        ['usr_id'] = usr_id,
        ['exp'] = a_exp,
        ['v_code1'] = v_code1
    }

    local r_payload = {
        ['usr_id'] = usr_id,
        ['exp'] = r_exp,
        ['v_code2'] = v_code2
    }

    a_payload = base64.encode(json.encode(a_payload))
    r_payload = base64.encode(json.encode(r_payload))

    local a_sign = base64.encode(a_hmac:final(a_payload))
    local r_sign = base64.encode(r_hmac:final(r_payload))

    local a_token = a_payload .. '.' .. a_sign
    local r_token = r_payload .. '.' .. r_sign

    return a_token, r_token, a_exp, v_code1, v_code2
end

function lib_auth:renew_tokens(db, token, ticket, secret1, secret2, session_lifetime, refresh_lifetime)
    local res = {}
    local session = {}

    res.token = lib_string:split(token, '.')
    if (#res.token ~= 2) then
        return 'bad token!'
    end

    local t_hmac = hmac.new(secret1 .. secret2, 'sha512')

    if (base64.encode(t_hmac:final(res.token[2])) ~= ticket) then
        return 'invalid ticket!'
    end

    res.token[1] = json.decode(base64.decode(res.token[1]))

    res.session = db:execparams('SELECT * FROM auth.sessions WHERE r_token = $1 AND usr_id = $2', token, res.token[1]['usr_id'])

    if (res.session == wpgsql.select_ok) then
        session = db:to_obj()
    end

    if (session and #session == 1) then
        local a_token, r_token, a_exp, v_code1, v_code2 = self:new_token(
            res.token[1]['usr_id'],
            secret1,
            secret2,
            session_lifetime,
            refresh_lifetime
        )

        db:bind('auth', 'sessions')
        db:where('=', 'id', tonumber(session[1]['id']))
        res.session_upd = db:update({
            ['r_token'] = r_token,
            ['a_exp'] = a_exp,
            ['v_code1'] = v_code1,
            ['v_code2'] = v_code2,
            ['active'] = true
        })

        if (res.session_upd == wpgsql.insert_ok) then
            return {['a_token'] = a_token, ['r_token'] = r_token}
        else
            return 'update: ' .. res.session_upd
        end
    end

    return 'no session!'
end

function lib_auth:login(db, usr, passwd, secret1, secret2, session_lifetime, refresh_lifetime)
    local res = {}
    local user = {}
    local session = {}

    res.user = db:execparams('SELECT * FROM auth.users WHERE usr_name = $1', usr)

    if (res.user == wpgsql.select_ok) then
        user = db:to_obj()
    end

    if (user and #user == 1) then
        res.pass_chk = bcrypt.verify(passwd, user[1]['passwd'])
    end

    if res.pass_chk then
        res.usr_id = tonumber(user[1]['id'])
        res.session = db:execparams('SELECT id FROM auth.sessions WHERE usr_id = $1', res.usr_id)
    else
        return 'not authenticated!'
    end

    if (res.session == wpgsql.select_ok) then
        session = db:to_obj()
    end

    if (session and #session == 1) then
        local a_token, r_token, a_exp, v_code1, v_code2 = self:new_token(
            res.usr_id,
            secret1,
            secret2,
            session_lifetime,
            refresh_lifetime
        )

        db:bind('auth', 'sessions')
        db:where('=', 'id', tonumber(session[1]['id']))
        res.session_upd = db:update({
            ['r_token'] = r_token,
            ['a_exp'] = a_exp,
            ['v_code1'] = v_code1,
            ['v_code2'] = v_code2,
            ['active'] = true
        })

        if (res.session_upd == wpgsql.insert_ok) then
            return {['a_token'] = a_token, ['r_token'] = r_token}
        else
            return 'update: ' .. res.session_upd
        end
    end

    if (session and #session > 1) then
        db:bind('auth', 'sessions')
        db:where('=', 'id', tonumber(session[1]['id']))
        res.session_del = db:delete()

        if (res.session_del == wpgsql.insert_ok) then
            return 'duplicated session!'
        else
            return 'delete: ' .. res.session_del
        end
    end

    if (res.pass_chk and not session) then
        local a_token, r_token, a_exp, v_code1, v_code2 = self:new_token(
            res.usr_id,
            secret1,
            secret2,
            session_lifetime,
            refresh_lifetime
        )

        db:bind('auth', 'sessions')
        res.session_ins = db:insert('', res.usr_id, r_token, a_exp, v_code1, v_code2, true)

        if (res.session_ins == wpgsql.insert_ok) then
            return {['a_token'] = a_token, ['r_token'] = r_token}
        else
            return 'insert: ' .. res.session_ins
        end
    end

    return 'authentication error!'
end

function lib_auth:logout(db, usr_id)
    db:bind('auth', 'sessions')
    db:where('=', 'usr_id', usr_id)
    local res = db:update({['active'] = false})

    if (res == wpgsql.insert_ok) then
        return 'logout'
    else
        return res
    end
end

--Users
function lib_auth:chk_usr(db, usr)
    local res = {}
    local user = {}

    res.user = db:execparams('SELECT id FROM auth.users WHERE usr_name= $1', usr)

    if (res.user == wpgsql.select_ok) then
        user = db:to_obj()
    end

    if (user and #user == 1) then
        return tonumber(user[1]['id'])
    end

    return false
end

function lib_auth:add_usr(db, usr, passwd, bcrypt_rounds)
    local res = {}
    res.usr_id = self:chk_usr(db, usr)

    if res.usr_id then
        return 'user already exist!'
    end

    res.hash = bcrypt.digest(passwd, bcrypt_rounds)
    res.verify = bcrypt.verify(passwd, res.hash)

    if res.verify then
        db:bind('auth', 'users')
        res.usr_ins = db:insert('', usr, res.hash)
    end

    if (res.usr_ins == wpgsql.insert_ok) then
        res.usr_id = self:chk_usr(db, usr)

        if (type(res.usr_id) ~= 'number') then
            return false
        end

        db:bind('auth', 'sessions')
        res.usr_session_ins = db:insert('', res.usr_id, 'empty', os.time(), 'empty', 'empty', false)
    end

    if (res.usr_session_ins == wpgsql.insert_ok) then
        return true
    end

    return false
end

function lib_auth:del_usr(db, usr)
    local res = {}
    res.usr_id = self:chk_usr(db, usr)

    if (type(res.usr_id) ~= 'number') then
        return false
    end

    db:bind('auth', 'users')
    db:where('=', 'id', res.usr_id)--use where if db user don't have USAGE permissions on information_schema
    res.usr_del = db:delete()

    if (res.usr_del == wpgsql.insert_ok) then
        return true
    end

    return false
end

function lib_auth:rename_usr(db, usr, new_usr)
    local res = {}
    res.usr_id = self:chk_usr(db, usr)

    if (type(res.usr_id) ~= 'number') then
        return false
    end

    db:bind('auth', 'users')
    db:where('=', 'id', res.usr_id)
    res.usr_rename = db:update({usr_name = new_usr})

    if (res.usr_rename == wpgsql.insert_ok) then
        return true
    end

    return false
end

function lib_auth:chpasswd_usr(db, usr, new_passwd, bcrypt_rounds)
    local res = {}
    res.usr_id = self:usr_chk(db, usr)

    if (type(res.usr_id) ~= 'number') then
        return false
    end

    res.hash = bcrypt.digest(new_passwd, config.bcrypt_rounds)
    res.verify = bcrypt.verify(new_passwd, res.hash)

    if res.verify then
        db:bind('auth', 'users')
        db:where('=', 'id', res.usr_id)
        res.usr_chpasswd = db:update({passwd = res.hash})
    end

    if (res.usr_chpasswd == wpgsql.insert_ok) then
        return true
    end

    return false
end

function lib_auth:get_usrs(db)
    local res = ''
    res = db:execute('SELECT id, usr_name FROM auth.users')

    if (res == wpgsql.select_ok) then
        return db:to_obj()
    end

    return false
end

--Groups
function lib_auth:chk_grp(db, grp)
    local res = {}
    local group = {}
    res.group = db:execparams('SELECT id FROM auth.groups WHERE grp_name= $1', grp)

    if (res.group == wpgsql.select_ok) then
        group = db:to_obj()
    end

    if (group and #group == 1) then
        return tonumber(group[1]['id'])
    end

    return false
end

function lib_auth:add_grp(db, grp, description)
    local res = {}
    res.grp_id = self:chk_grp(db, grp)

    if res.grp_id then
        return 'group already exist!'
    end

    db:bind('auth', 'groups')
    res.grp_ins = db:insert('', grp, description)

    if (res.grp_ins == wpgsql.insert_ok) then
        return true
    end

    return false
end

function lib_auth:del_grp(db, grp)
    local res = {}
    res.grp_id = self:chk_grp(db, grp)

    if (type(res.grp_id) ~= 'number') then
        return false
    end

    db:bind('auth', 'groups')
    db:where('=', 'id', res.grp_id)--use where if db user don't have USAGE permissions on information_schema
    res.grp_del = db:delete()

    if (res.grp_del == wpgsql.insert_ok) then
        return true
    end

    return false
end

function lib_auth:rename_grp(db, grp, new_grp, description)
    local res = {}
    res.grp_id = self:chk_grp(db, grp)

    if (type(res.grp_id) ~= 'number') then
        return false
    end

    db:bind('auth', 'groups')
    db:where('=', 'id', res.grp_id)
    res.grp_rename = db:update({grp_name = new_grp, ['description'] = description})

    if (res.grp_rename == wpgsql.insert_ok) then
        return true
    end

    return false
end

function lib_auth:get_grps(db)
    local res = ''
    res = db:execute('SELECT * FROM auth.groups')

    if (res == wpgsql.select_ok) then
        return db:to_obj()
    end

    return false
end

--Users and Groups
function lib_auth:chk_usr_grp(db, usr, grp)
    local res = {}
    local user_group = {}
    res.usr_id = self:chk_usr(db, usr)
    res.grp_id = self:chk_grp(db, grp)

    if (type(res.usr_id) == 'number' and type(res.grp_id) == 'number') then
        res.user_group = db:execparams(
            'SELECT id FROM auth.users_groups WHERE usr_id = $1 AND grp_id = $2',
            res.usr_id,
            res.grp_id
        )

        if (res.user_group == wpgsql.select_ok) then
            user_group = db:to_obj()
        end

        if (user_group and #user_group == 1) then
            return tonumber(user_group[1]['id']), res.usr_id, res.grp_id
        end
    end
    
    return false, res.usr_id, res.grp_id
end

function lib_auth:add_usr_grp(db, usr, grp)
    local res = {}
    res.usr_grp_id, res.usr_id, res.grp_id = self:chk_usr_grp(db, usr, grp)

    if (type(res.usr_grp_id) == 'number') then
        return res.usr_grp_id
    end

    if (type(res.usr_id) == 'number' and type(res.grp_id) == 'number') then
        db:bind('auth', 'users_groups')
        res.usr_grp_ins = db:insert('', res.usr_id, res.grp_id)

        if (res.usr_grp_ins == wpgsql.insert_ok) then
            return true
        end
    end

    return false
end

function lib_auth:del_usr_grp(db, usr, grp)
    local res = {}
    res.usr_grp_id = self:chk_usr_grp(db, usr, grp)

    if (type(res.usr_grp_id) ~= 'number') then
        return false
    end

    db:bind('auth', 'users_groups')
    db:where('=', 'id', res.usr_grp_id)
    res.usr_grp_del = db:delete()

    if (res.usr_grp_del == wpgsql.insert_ok) then
        return true
    end

    return false
end

function lib_auth:get_usrs_grps(db)
    local res = ''
    res = db:execute('SELECT usr_id, grp_id FROM auth.users_groups')

    if (res == wpgsql.select_ok) then
        return db:to_obj()
    end

    return false
end

function lib_auth:get_usrs_grps2(db)
    local res = ''
    res = db:execute('SELECT * FROM auth.users_in_groups ORDER BY grp_id, usr_name')

    if (res == wpgsql.select_ok) then
        return db:to_obj()
    end

    return false
end

function lib_auth:get_usrs_wt_grps(db)
    local res = ''
    res = db:execute('SELECT * FROM auth.users_without_groups ORDER BY usr_name')

    if (res == wpgsql.select_ok) then
        return db:to_obj()
    end

    return false
end

--Units
function lib_auth:chk_unit(db, unit)
    local res = {}
    local t_unit = {}

    res.unit = db:execparams('SELECT id FROM auth.units WHERE unit_name = $1', unit)

    if (res.unit == wpgsql.select_ok) then
        t_unit = db:to_obj()
    end

    if (t_unit and #t_unit == 1) then
        return tonumber(t_unit[1]['id'])
    end

    return false
end

--added exports
function lib_auth:add_unit(db, unit, exports)
    local res = {}
    res.unit_id = self:chk_unit(db, unit)

    if res.unit_id then
        return 'unit already exist!'
    end

    db:bind('auth', 'units')
    res.unit_ins = db:insert('', unit, exports)

    if (res.unit_ins == wpgsql.insert_ok) then
        return true
    end

    return false
end

function lib_auth:del_unit(db, unit)
    local res = {}
    res.unit_id = self:chk_unit(db, unit)

    if (type(res.unit_id) ~= 'number') then
        return false
    end

    db:bind('auth', 'units')
    db:where('=', 'id', res.unit_id)--use where if db user don't have USAGE permissions on information_schema
    res.unit_del = db:delete()

    if (res.unit_del == wpgsql.insert_ok) then
        return true
    end

    return false
end

function lib_auth:get_units(db)
    local res = ''
    res = db:execute('SELECT id, unit_name FROM auth.units')

    if (res == wpgsql.select_ok) then
        return db:to_obj()
    end

    return false
end

--Policies
function lib_auth:chk_policy(db, grp, unit)
    local res = {}
    local policy = {}
    res.grp_id = self:chk_grp(db, grp)
    res.unit_id = self:chk_unit(db, unit)

    if (type(res.grp_id) == 'number' and type(res.unit_id) == 'number') then
        res.policy = db:execparams(
            'SELECT id FROM auth.groups_policies WHERE grp_id = $1 AND unit_id = $2',
            res.grp_id,
            res.unit_id
        )

        if (res.policy == wpgsql.select_ok) then
            policy = db:to_obj()
        end

        if (policy and #policy == 1) then
            return tonumber(policy[1]['id']), res.grp_id, res.unit_id
        end
    end

    return false, res.grp_id, res.unit_id
end

function lib_auth:add_policy(db, grp, unit, r_p, w_p)
    local res = {r_p = false, w_p = false}
    res.policy_id, res.grp_id, res.unit_id = self:chk_policy(db, grp, unit)

    if r_p then
        res.r_p = true
    end

    if w_p then
        res.w_p = true
    end

    if (type(res.policy_id) == 'number') then
        return res.policy_id
    end

    if (type(res.grp_id) == 'number' and type(res.unit_id) == 'number') then
        db:bind('auth', 'groups_policies')
        res.groups_policies_ins = db:insert('', res.grp_id, res.unit_id, res.r_p, res.w_p)

        if (res.groups_policies_ins == wpgsql.insert_ok) then
            return true
        end
    end
    
    return false
end

function lib_auth:del_policy(db, grp, unit)
    local res = {}
    res.policy_id = self:chk_policy(db, grp, unit)

    if (type(res.policy_id) ~= 'number') then
        return false
    end

    db:bind('auth', 'groups_policies')
    db:where('=', 'id', res.policy_id)--use where if db user don't have USAGE permissions on information_schema
    res.policy_del = db:delete()

    if (res.policy_del == wpgsql.insert_ok) then
        return true
    end

    return false
end

function lib_auth:update_policy(db, grp, unit, r_p, w_p)
    local res = {r_p = false, w_p = false}
    res.policy_id = self:chk_policy(db, grp, unit)

    if (type(res.policy_id) ~= 'number') then
        return false
    end

    if r_p then
        res.r_p = true
    end

    if w_p then
        res.w_p = true
    end

    db:bind('auth', 'groups_policies')
    db:where('=', 'id', res.policy_id)
    res.policy_update = db:update({r_p = res.r_p, w_p = res.w_p})

    if (res.policy_update == wpgsql.insert_ok) then
        return true
    end

    return false
end

function lib_auth:get_policies(db, unit)
    local res = {}
    res.unit_id = self:chk_unit(db, unit)

    if (type(res.unit_id) ~= 'number') then
        return false
    end

    res.policies_get = db:execparams(
        'SELECT grp_id, r_p, w_p FROM auth.groups_policies WHERE unit_id = $1',
        res.unit_id
    )

    if (res.policies_get == wpgsql.select_ok) then
        return db:to_obj()
    end
    
    return false
end

function lib_auth:get_grp_policies(db, grp)
    local res = {}
    res.grp_id = self:chk_grp(db, grp)

    if (type(res.grp_id) ~= 'number') then
        return false
    end

    res.policies_get = db:execparams(
        'SELECT unit_id, r_p, w_p FROM auth.groups_policies WHERE grp_id = $1',
        res.grp_id
    )

    if (res.policies_get == wpgsql.select_ok) then
        return db:to_obj()
    end
    
    return false
end

return lib_auth