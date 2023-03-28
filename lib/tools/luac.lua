local function luac(filename)
    local bc_ok, bc = pcall(loadfile, filename, 't', {})

    if (not bc_ok) then
        return false, bc
    end
    
    local cbc_ok, cbc = pcall(string.dump, bc)

    if (not cbc_ok) then
        return false, cbc
    end

    return cbc
end

return luac