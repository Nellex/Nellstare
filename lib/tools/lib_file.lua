local fs = require('lfs')

local lib_file = {}

function lib_file:read(path)
    local fd = io.open(path, 'r')

    if fd then
        local f = fd:read('*a')
        fd:close()
        fd = nil

        return f
    end

    return false
end

function lib_file:write(path, content)
    local fd = io.open(path, 'w')

    if fd then
        local f = fd:write(content)
        fd:close()
        fd = nil

        if f then
            f = nil

            return true
        end
    end

    return false
end

function lib_file:is_exist(path)
    if (type(path) ~= 'string') then
        return false
    end
    
    local mode = fs.attributes(path, 'mode')

    if (mode and (mode == 'directory' or mode == 'file')) then
        return true
    end

    return false
end

function lib_file:get_path(full_path)
    if (type(full_path) ~= 'string') then
        return false, 'full_path must be a string!'
    end

    local pos = string.find(string.reverse(full_path), '/', 1, true)

    if (not pos) then
        return false, 'full_path is incorrect!'
    end

    return string.sub(full_path, 1, #full_path - pos)
end

function lib_file:get_filename(full_path)
    if (type(full_path) ~= 'string') then
        return false, 'full_path must be a string!'
    end

    local pos = string.find(string.reverse(full_path), '/', 1, true)

    if (not pos) then
        return false, 'full_path is incorrect!'
    end

    return string.sub(full_path, -(pos - 1))
end

return lib_file