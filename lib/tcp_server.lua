local ev = require('ev')
local socket = require('posix.sys.socket')
local unistd = require('posix.unistd')

local function new_server(host, port, loop, cb, rcv_cnt, mode)
    local host = host or '127.0.0.1'
    local port = port or 8193
    local rcv_cnt = tonumber(rcv_cnt)
    local mode = mode or ''
    local sock_config = {
        ['family'] = socket.AF_INET,
        ['protocol'] = socket.IPPROTO_TCP,
        ['addr'] = host,
        ['port'] = port
    }

    srv_fd = socket.socket(socket.AF_INET, socket.SOCK_STREAM, 0)
    socket.setsockopt (srv_fd, socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    socket.setsockopt (srv_fd, socket.SOL_SOCKET, socket.SO_RCVTIMEO, 0, 0)
    socket.setsockopt (srv_fd, socket.SOL_SOCKET, socket.SO_SNDTIMEO, 0, 0)
    socket.setsockopt (srv_fd, socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)

    local bind_st = socket.bind(srv_fd, sock_config)

    if (bind_st == 0) then
        socket.listen(srv_fd, 2048)

        local listener_io = ev.IO.new(function(loop)
            function client(client_fd)
                if (type(client_fd) == 'number' and client_fd > 0) then
                    return ev.IO.new(function(loop, read_io)
                        local data = socket.recv(client_fd, rcv_cnt)

                        if (not data or type(data) == 'number' or #data == 0) then
                            read_io:stop(loop)
                            socket.shutdown(client_fd, socket.SHUT_RDWR)
                            unistd.close(client_fd)

                            return
                        end

                        read_io:stop(loop)

                        local response = cb(data)

                        return ev.IO.new(function(loop, write_io)
                            repeat
                                bytes = socket.send(client_fd, response)

                                if (not bytes) then
                                    print('send err!')
                                    break
                                end
                            until bytes == #response

                            write_io:stop(loop)

                            if (mode == 'forever') then
                                return client(client_fd)
                            else
                                socket.shutdown(client_fd, socket.SHUT_RDWR)
                                unistd.close(client_fd)
                            end
                        end, client_fd, ev.WRITE):start(loop)
                    end, client_fd, ev.READ):start(loop)
                end
            end

            client(socket.accept(srv_fd))

        end, srv_fd, ev.READ)

        listener_io:start(loop)

        return srv_fd, listener_io
    end
end

return new_server