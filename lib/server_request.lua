local base64 = require('lib.base64') --; base64.alpha("base64url")
local deepcopy = require('lib.tools.deepcopy')
local json = require('cjson')
local hmac = require('openssl.hmac')
local socket = require('posix.sys.socket')
local unistd = require('posix.unistd')
local lib_string = require('lib.tools.lib_string')

local server_request = {}
server_request.args = {['meth'] = ''}
server_request.host = '127.0.0.1'
server_request.port = 8193
server_request.req = ''
server_request.res_len = 5
server_request.secret = ''
server_request.template = '${request}'

function server_request:new()
    return deepcopy(self)
end

function server_request:send()
    local sock_config = {
        ['family'] = socket.AF_INET,
        ['protocol'] = socket.IPPROTO_TCP,
        ['addr'] = self.host,
        ['port'] = self.port
    }

    repeat
        clnt_fd = socket.socket(socket.AF_INET, socket.SOCK_STREAM, 0)
    until clnt_fd

    socket.setsockopt (clnt_fd, socket.SOL_SOCKET, socket.SO_RCVTIMEO, 0, 0)
    socket.setsockopt (clnt_fd, socket.SOL_SOCKET, socket.SO_SNDTIMEO, 0, 0)
    socket.setsockopt (clnt_fd, socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)

    local conn_st

    for i=1, 6 do
        conn_st = socket.connect(clnt_fd, sock_config)

        if (conn_st == 0) then
            break
        end
    end

    if (conn_st == 0) then
        if (clnt_fd < 3) then
            return false, 'server request: reconnect, not fd.'
        end

        local req = {
            ['req'] = self.req,
            ['args'] = self.args
        }

        req = base64.encode(json.encode(req))

        local v_hmac = hmac.new(self.secret, 'sha512')

        local req_sign = base64.encode(v_hmac:final(req))

        v_hmac = nil

        req = req .. '.' .. req_sign

        local rendered_template = lib_string:replace(self.template, {['request'] = req})

        repeat
            res = socket.send(clnt_fd, rendered_template)
        until res == #rendered_template

        rendered_template = nil
        req = nil

        local res_str = socket.recv(clnt_fd, self.res_len)

        socket.shutdown(clnt_fd, socket.SHUT_RDWR)
        unistd.close(clnt_fd)

        return true, res_str
    end

    return false, 'server request: connection failed! Errno: ' .. tostring(conn_st)
end

return server_request