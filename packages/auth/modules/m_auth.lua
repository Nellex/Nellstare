do--auth module sub
    if (not config.use_db) then
        error('"config.use_db" not defined!', 0)
    end

    local base64 = require('lib.base64') ;base64.alpha("base64url")
    local db = require('lib.db.wpgsql')
    local hmac = require('openssl.hmac')
    local lib_string = require('lib.tools.lib_string')

    local args = get_args()
    local MODULE_KEY = '${module_key}'

    local auth_h_user, auth_h_user_err = send_form({
        module_key = MODULE_KEY,
        target_type = 'signal',
        target = 'get_key',
        args = {
            key = 'auth_h_user'
        }
    })

    if (not auth_h_user) then
        error(auth_h_user_err, 0)
    end

    local auth_h_passwd, auth_h_passwd_err = send_form({
        module_key = MODULE_KEY,
        target_type = 'signal',
        target = 'get_key',
        args = {
            key = 'auth_h_passwd'
        }
    })

    if (not auth_h_passwd) then
        error(auth_h_passwd_err, 0)
    end

    local secret1, secret1_err = send_form({
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

    local secret2, secret2_err = send_form({
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

    local db_objects = {}
    local res = {}

    res.errors = {
        [1] = 'not authenticated!',
        [2] = 'bad token!',
        [3] = 'invalid token!',
        [4] = 'expired token!',
        [5] = 'no token!'
    }

    local auth_db = db:new()

    local m_auth = {}

    function m_auth:token_validate() --N1
        if (not args.token) then
            auth_db:disconnect()
            error(res.errors[5], 0)
        end 

        res.token = lib_string:split(args.token, '.')

        if (#res.token ~= 2) then
            auth_db:disconnect()
            error(res.errors[2], 0)
        end

        local secret = secret1
        res.token_type = 'access'
        
        if ((json.decode(base64.decode(res.token[1])) or {})['v_code2']) then
            res.token_type = 'refresh'
            secret = secret2
        end

        local v_hmac = hmac.new(secret, 'sha512')

        if (base64.encode(v_hmac:final(res.token[1])) ~= res.token[2]) then
            auth_db:disconnect()
            error(res.errors[3], 0)
        end
    end

    function m_auth:session_chk() --N2
        res.token[1] = json.decode(base64.decode(res.token[1]))

        res.session = auth_db:execparams('SELECT * FROM auth.sessions WHERE usr_id = $1', res.token[1]['usr_id'])

        if (res.session == db.select_ok) then
            db_objects.session = auth_db:to_obj()
        else
            auth_db:disconnect()
            error(res.session, 0)
        end

        if (not db_objects.session) then
            auth_db:disconnect()
            error(res.errors[2], 0)
        end

        if (#db_objects.session > 1) then
            auth_db:disconnect()
            error('duplicated session!')
        end

        if (db_objects.session[1]['active'] == 'f') then
            auth_db:disconnect()
            error(res.errors[1], 0)
        end
    end

    function m_auth:token_chk() --N3
        local cur_time = os.time()

        if (res.token_type == 'refresh') then
            if (args.token ~= db_objects.session[1]['r_token']) then
                auth_db:disconnect()
                error(res.errors[3], 0)
            end
    
            if (res.token[1]['exp'] < cur_time) then
                return false, res.errors[4]
            end

            if (res.token[1]['v_code2'] ~= db_objects.session[1]['v_code2']) then
                auth_db:disconnect()
                error(res.errors[3], 0)
            end

            return true, 'all ok!'
        end

        if (res.token_type == 'access') then
            if (res.token[1]['exp'] ~= tonumber(db_objects.session[1]['a_exp'])) then
                auth_db:disconnect()
                error(res.errors[3], 0)
            end

            if (res.token[1]['exp'] < cur_time) then return false, res.errors[4] end

            if (res.token[1]['v_code1'] ~= db_objects.session[1]['v_code1']) then
                auth_db:disconnect()
                error(res.errors[3], 0)
            end

            return true, 'all ok!'
        end

        auth_db:disconnect()
        error(res.errors[2], 0)
    end

    --return: true or false, message, read policy (1 or 0), write policy (1 or 0)
    function m_auth:unit_pol_chk(unit)
        --get user=>groups
        res.user_groups = auth_db:execparams('SELECT grp_id FROM auth.users_groups WHERE usr_id = $1', id())

        if (res.user_groups == db.select_ok) then
            db_objects.user_groups = auth_db:to_obj()
        else
            return false, res.user_groups
        end

        res.unit_id = auth_db:execparams('SELECT id FROM auth.units WHERE unit_name = $1', unit)

        if (res.unit_id == db.select_ok) then
            db_objects.unit_id = auth_db:to_obj()
        else
            return false, res.unit_id
        end

        if (db_objects.user_groups and db_objects.unit_id) then
            local query = 'SELECT * FROM auth.groups_policies WHERE unit_id = ' .. auth_db:add_param(tonumber(db_objects.unit_id[1]['id'])) .. ' AND grp_id IN ('

            for i=1, #db_objects.user_groups do
                local sep = ', '

                if (i == #db_objects.user_groups) then sep = ')' end

                query = query .. auth_db:add_param(tonumber(db_objects.user_groups[i]['grp_id'])) .. sep
            end

            res.groups_policies = auth_db:execparams(query, table.unpack(auth_db.params))
        else
            return false, 'unit name incorrect or user don\'t have privileges!'
        end

        if (res.groups_policies == db.select_ok) then
            db_objects.groups_policies = auth_db:to_obj()
        else
            return false, res.groups_policies
        end

        if db_objects.groups_policies then
            local r_p, w_p = 0, 0

            if (#db_objects.groups_policies == 1) then
                if (db_objects.groups_policies[1]['r_p'] == 't') then
                    r_p = 1
                end

                if (db_objects.groups_policies[1]['w_p'] == 't') then
                    w_p = 1
                end
            end

            if (#db_objects.groups_policies > 1) then
                for i=1, #db_objects.groups_policies do
                    if (db_objects.groups_policies[i]['r_p'] == 't' and r_p == 0) then
                        r_p = 1
                    end

                    if (db_objects.groups_policies[i]['w_p'] == 't' and w_p == 0) then
                        w_p = 1
                    end
                end
            end

            if (r_p == 0 and w_p == 0) then
                return false, 'access denied!'
            else
                return true, 'access allowed!', r_p, w_p
            end
        else
            return false, 'not autorized!'
        end
    end

    function id()
        if (res.token and res.token[1]) then
            return res.token[1]['usr_id']
        end

        return 0
    end

    function get_pol(chk_mode)
        local chk_mode = chk_mode or 'r'

        if (chk_mode == 'r' and res.r_p == 1) then return true end

        if (chk_mode == 'w' and res.w_p == 1) then return true end

        if (chk_mode == 'rw' and res.r_p == 1 and  res.w_p == 1) then return true end

        return false
    end

    function save_cache()
        local ok, err = send_form({
            module_key = MODULE_KEY,
            target_type = 'signal',
            target = 'save_cache',
            args = {
                usr_id = id(),
                cache = deepcopy(service.cache)
            }
        })

        if (not ok) then
            return false
        end

        return true
    end

    function m_auth_run(unit, without_cache)
        res.connection_ok, res.connection_err = auth_db:connect(config.db_host, config.db_port, auth_h_user, auth_h_passwd, config.db_name)

        if (not res.connection_ok) then error(res.connection_err, 0) end

        m_auth:token_validate()
        m_auth:session_chk()
        res.token_chk, res.token_chk_msg = m_auth:token_chk()

        if (not res.token_chk) then
            auth_db:disconnect()
            error(res.token_chk_msg, 0)
        end

        if (res.token_type == 'refresh') then
            auth_db:disconnect()

            local t_hmac = hmac.new(secret1 .. secret2, 'sha512')

            -- Вызов выполняется от сервиса, в форме специально не указывается module_key
            local response_err = false

            service.response, response_err = send_form({
                target_type = 'signal',
                target = 'inreq',
                args = {
                    target_path = 'auth.auth',
                    meth = 'renew_tokens',
                    ticket = base64.encode(t_hmac:final(res.token[2])),
                    token = args.token
                }
            })

            if (not service.response) then
                service.response = response_err
            end

            error('handler_mode=1', 0)
        end

        if (res.token_type == 'access') then
            res.unit_pol_chk_ok, res.unit_pol_chk_msg, res.r_p, res.w_p = m_auth:unit_pol_chk(unit)
            auth_db:disconnect()

            if (not res.unit_pol_chk_ok) then
                error(res.unit_pol_chk_msg, 0)
            end

            if without_cache then
                return
            end

            service.cache = send_form({
                module_key = MODULE_KEY,
                target_type = 'signal',
                target = 'get_cache',
                args = {
                    usr_id = id()
                }
            })
        end
    end
end