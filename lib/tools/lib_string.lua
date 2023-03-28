local lib_string = {}

function lib_string:split(str, sep)
    local pat = '([^' .. sep .. ']+)'
    str = str or '%s'
    local t = {}
    local i = 1

    for split_str in string.gmatch(str, pat) do
        t[i] = split_str
        i = i + 1
    end
    
    return t
end

function lib_string:replace(sc, patch)
    for p_name, p_val in pairs(patch) do
        local m_str = '${' .. p_name .. '}'
        sc = string.gsub(sc, m_str, p_val)
    end
    
    return sc
end

return lib_string