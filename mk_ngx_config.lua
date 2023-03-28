package.path = './?;./?.lua;/usr/local/share/lua/5.2/?.lua;/usr/local/share/lua/5.2/?/init.lua;/usr/local/lib/lua/5.2/?.lua;/usr/local/lib/lua/5.2/?/init.lua'
package.cpath = '/usr/local/lib/lua/5.2/?.so;/usr/local/lib/lua/5.2/?'


ngx_config_tool = require('lib.tools.ngx_config_tool')

ngx_config_tool.properties.l10_config_file_path = 'config/config.json'
ngx_config_tool.properties.l10_project_file_path = 'project/project.json'

ngx_config_tool.properties.public_srv_cert_file_path = 'localhost.pem'
ngx_config_tool.properties.public_srv_key_file_path = 'localhost.key'
ngx_config_tool.properties.public_srv_dhparam_file_path = 'dh2048.pem'

ngx_config_tool:init()

ngx_config = ngx_config_tool:mk_config()

ngx_config_tool:write(ngx_config, 'ngx/nefsrv_test.conf')