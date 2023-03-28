-- obj = {  <--Object name
--    __name = 'obj', <--field '__name' must be contain value eq Object name
--    ...
-- }
-- Then error wrapper can write messages with fullnamed methods.

-- If set to "debug.safe = true" then error_wrapper will remove all methods from debug library, besides 'getinfo' method.

local json = require('cjson')
local pretty_json = require('lib.tools.pretty_json')

local error_wrapper = {}

function error_wrapper:mk_safe_debug()
    for f_name in pairs(debug) do
        if (f_name ~= 'getinfo') then
            debug[f_name] = nil
        end
    end
end

function error_wrapper:new(parameter, err)
    parameter = parameter or debug.getinfo(2, "n").name

    if (type(parameter) == 'table' and parameter.__name) then
        parameter = tostring(parameter.__name) .. ':' .. tostring(debug.getinfo(2, "n").name)
    end

    if (type(parameter) ~= 'string') then
        parameter = tostring(debug.getinfo(2, "n").name)
    end

    return {
        ['parameter'] = parameter,
        ['error'] = err
    }
end

function error_wrapper:add(errors, parameter, err)
    if (type(errors) ~= 'table') then
        errors = {}
    end

    table.insert(errors, self:new(parameter, err))
end

function error_wrapper:chain(parameter, err, mark)
    parameter = parameter or tostring(debug.getinfo(2, "n").name)

    if (type(err) ~= 'table') then
        err = {
            ['parameter'] = 'Error wrapper: chaining error! Error value is not table!'
        }
    end

    -- debug_err = pretty_json(err)
    -- print('error_wrapper debug:', parameter, debug_err)

    if (type(parameter) == 'table' and parameter.__name) then
        parameter = tostring(parameter.__name) .. ':' .. tostring(debug.getinfo(2, "n").name)
    end

    if (type(parameter) ~= 'string') then
        parameter = tostring(debug.getinfo(2, "n").name)
    end

    if mark then
        parameter = parameter .. '[' .. tostring(mark) .. ']'
    end

    if err[1] then
        return {
            ['parameter'] = parameter,
            ['error'] = err
        }
    end

    err.parameter = parameter .. '==>' .. err.parameter

    return err
end

-- options = {
--     is_critical = true,
--     err_cb = print
-- }
function error_wrapper:error(parameter, err, options)
    if (type(err) == 'table') then
        err = pretty_json(err)
    elseif (type(err) == 'number' or type(err) == 'boolean') then
        err = tostring(err)
    end

    if (type(parameter) == 'table' and parameter.__name) then
        parameter = tostring(parameter.__name) .. ':' .. tostring(debug.getinfo(2, "n").name)
    end

    if (type(parameter) ~= 'string') then
        parameter = tostring(debug.getinfo(2, "n").name)
    end

    if options.is_critical then
        print(parameter .. '==>\n' .. err)
        os.exit()
    end

    print(parameter .. '==>\n' .. err)
end

if debug.safe then
    error_wrapper:mk_safe_debug()
end

return error_wrapper