--get_stamp
local function get_stamp()
    return tonumber(os.date('%H',os.time())) * 60 + tonumber(os.date('%M',os.time()))
end

return get_stamp