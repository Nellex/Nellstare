local lib_string = require('lib.tools.lib_string')
local valua = require('lib.valua')

local netresource = {}

--punycode not implemented!
--'^%w+[%w%-]*[%w%.]*%.%a%a+%:[1-9][0-9]*$' - not working, and therefore this function so bigger:)
function netresource:is_fqdn(value, wport)
    if (type(value) ~= 'string') then
        return false, 'value must be a string!'
    end

    if (#value < 4) then
        return false --'value must be contain minimal limit - 4 chars!'
    end

    if (value:match('%.%.')) then
        return false
    end

    if (value:match('^[%.].')) then
        return false
    end

    if (value:match('%-%-')) then
        return false
    end

    if (value:match('%a%a+%.$') and not wport) then
        value = value:sub(1, -2)
    end

    local subs = lib_string:split(value, '.')

    if (#subs > 1) then
        for i=1, #subs-1 do
            if (not string.match(subs[i], '^%w+[%w%-]*%w+$')) then
                return false
            end
        end
    end

    if wport then
        local dn, port = string.match(subs[#subs], '^(%a%a+)%:([1-9][0-9]*)$')

        if (not dn or not port) then
            return false
        end

        if (tonumber(port) > 65535) then
            return false
        end

        if (#value > (253 + #port + 1)) then
            return false
        end
    else
        if (not string.match(subs[#subs], '%a%a+$')) then
            return false
        end

        if (#value > 253) then
            return false
        end
    end

    return true
end

--basic url validation
--only http or https
--userinfo not implemented, no checks for query and fragmets
function netresource:is_url(value, path_end)
    if (type(value) ~= 'string') then
        return false --, 'value must be a string!'
    end

    local host_idx = 2

    if (value:sub(1, 2) == '//') then
        host_idx = 1
    end

    local subs = lib_string:split(value, '/')

    if (not string.match(subs[1], '^http[s]?%:$') and host_idx == 2) then
        return false --, 'scheme not defined!'
    end

    local host = false

    if (valua._ip(subs[host_idx], true)) then
        host = true
    end

    if (not host and self:is_fqdn(subs[host_idx], true)) then
        host = true
    end

    if (not host and valua._ip(subs[host_idx])) then
        host = true
    end

    if (not host and self:is_fqdn(subs[host_idx])) then
        host = true
    end

    if (not host) then
        return false
    end

    if (#subs == 1 and host and host_idx == 1) then
        return true
    end

    if (#subs == 2 and host) then
        return true
    end

    if (#subs > 3) then
        for i=3, #subs-1 do
            if (string.match(subs[i], '[^%w%.%,%:%;%%%*%+%-_%$%&%\'%~%!]') or string.match(subs[i], '%%%%+')) then
                return false
            end
        end
    end

    if (path_end and (string.match(subs[#subs], '[^%w%.%,%:%;%%%*%+%-_%$%&%\'%~%!]') or string.match(subs[#subs], '%%%%+'))) then
        return false
    elseif (string.match(subs[#subs], '[^%w%.%,%:%;%?%%%*%+%-_%$%#%@%&%=%\'%~%!]')) then
        return false
    end

    return true
end

return netresource