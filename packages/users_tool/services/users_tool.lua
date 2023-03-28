--!!!CUSTOM PROPERTIES IN service!!!
--Use "exports" for set custom access property from your service to profiles system
--function test(arg1, arg2)
--  local exports = {'new_property', 'your comment', 'option1', 'option2', 'option3'}
--end
--  property name----------^       comment--^            ^----------^----------^--custom options of property (option1 sets by default)
--                         ^--property name must be unique and readable
_ENV()
m_auth_run('users_tool')

base64 = require('lib.base64'); base64.alpha("base64url")
local args = get_args()

if (args.meth and args.meth == 'launch') then
    response = {
        ['url'] = string.format('%s/%s/launcher.js', config.js_url, service.package_name)
    }
end

service.response = json.encode(response)