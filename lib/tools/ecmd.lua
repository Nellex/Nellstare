local function ecmd(cmd)
    local out = ''
    if (type(cmd) == 'string') then
        cmd = cmd .. ' > ecmd.tmp'
        os.execute('rm -f ./ecmd.tmp')
        os.execute(cmd)
        file = io.open('./ecmd.tmp', 'r')
        if file then
            out = file:read('*a')
            file:close()
        end
        os.execute('rm -f ./ecmd.tmp')
        return out
    end
end

return ecmd