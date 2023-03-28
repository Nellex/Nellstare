local chronos = require('chronos')

local gp = {}
gp.default_chars = 'ABCxD7EFGH1IJKL8MNwO3P0QRST4UVWX*YZabcde6fghijk9lmnop5qrstuvyz2'

function gp:generate(pass_len, chars)
    local pass_len = pass_len or 16
    local res = ''
    local r = 0

    if (chars and type(chars) == 'string' and #chars > 10) then
        self.chars = chars
    else
        self.chars = self.default_chars
    end

    for i=0, pass_len + 2 do
        local a, b = math.modf(chronos.nanotime())
        local seed = tonumber(string.sub(b,3))
        math.randomseed(math.floor(seed))
        self.chars = string.sub(self.chars, 64, 64) .. string.sub(self.chars, 1,63)
        r = math.floor(math.random() * 64 - i)
        res = res .. string.sub(self.chars, r,r)
    end

    return string.sub(res, 1, pass_len)
end

return gp