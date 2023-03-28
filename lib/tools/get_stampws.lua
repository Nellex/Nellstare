--get_stamp with seconds
local function get_stampws()
    return tostring(tonumber(os.date('%H',os.time())) * 60 + tonumber(os.date('%M',os.time()))) .. os.date('%S',os.time())
end

return get_stampws