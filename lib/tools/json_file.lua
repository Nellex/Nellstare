local json = require('cjson')

local json_file = {}

function json_file:read(json_filename)
    if (not json_filename or type(json_filename) ~= 'string') then
        return false
    end

    local json_obj = ''
    local json_obj_fd = io.open(json_filename, 'r')

    if (not json_obj_fd) then
        return false
    end

    json_obj = json_obj_fd:read('*a')
    json_obj_fd:close()
    json_ok, json_obj = pcall(json.decode, json_obj)

    if (not json_ok) then
        return false
    end

    return json_obj
end

function json_file:write(json_filename, json_obj)
    if (not json_obj or type(json_obj) ~= 'table') then
        return false
    end

    if (not json_filename or type(json_filename) ~= 'string') then
        return false
    end

    local json_obj_fd = io.open(json_filename, 'w')

    if (not json_obj_fd) then
        return false
    end

    json_ok, json_obj = pcall(json.encode, json_obj)

    if (not json_ok) then
        return false
    end

    json_obj_fd:write(json_obj)
    json_obj_fd:close()
    
    return true
end

return json_file