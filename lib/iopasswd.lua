-- https://stackoverflow.com/questions/5787796/hide-password-with-asterisk-in-lua
-- by Egor Skriptunoff

local iopasswd = {
    ['backspace_key'] = '\127',
    __name = 'iopasswd'
}

function iopasswd.start()
    os.execute('stty -echo raw')
end

function iopasswd.finish()
    os.execute('stty sane')
end

function iopasswd.wait_key()
    return io.read(1)
end

function iopasswd:enter_passwd(msg, h_char, max_length)
    local pwd = ''
    io.write(msg or '')
    io.flush()
    self.start()

    repeat
        local c = self.wait_key()

        if (c == self.backspace_key) then
            if (#pwd > 0) then
                io.write'\b \b'
                pwd = pwd:sub(1, -2)
            end
        elseif (c ~= '\r' and #pwd < (max_length or 32)) then
            io.write(h_char or '*')
            pwd = pwd .. c
        end

        io.flush()
    until c == '\r'

   self.finish()
   io.write'\n'
   io.flush()

   return pwd
end

return iopasswd