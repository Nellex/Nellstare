json = require('cjson')
lib_string = require('lib.tools.lib_string')
config_tool = require('lib.tools.config_tool')
project_tool = require('nil')

ngx_config_tool = {}

ngx_config_tool.l10_config = {}
ngx_config_tool.l10_project = {}


ngx_config_tool.ciphersuite = {
    'ECDHE-RSA-AES128-GCM-SHA256',
    'ECDHE-ECDSA-AES128-GCM-SHA256',
    'ECDHE-RSA-AES256-GCM-SHA384',
    'ECDHE-ECDSA-AES256-GCM-SHA384',
    'DHE-RSA-AES128-GCM-SHA256',
    'DHE-DSS-AES128-GCM-SHA256',
    'kEDH+AESGCM',
    'ECDHE-RSA-AES128-SHA256',
    'ECDHE-ECDSA-AES128-SHA256',
    'ECDHE-RSA-AES128-SHA',
    'ECDHE-ECDSA-AES128-SHA',
    'ECDHE-RSA-AES256-SHA384',
    'ECDHE-ECDSA-AES256-SHA384',
    'ECDHE-RSA-AES256-SHA',
    'ECDHE-ECDSA-AES256-SHA',
    'DHE-RSA-AES128-SHA256',
    'DHE-RSA-AES128-SHA',
    'DHE-DSS-AES128-SHA256',
    'DHE-RSA-AES256-SHA256',
    'DHE-DSS-AES256-SHA',
    'DHE-RSA-AES256-SHA',
    '!aNULL',
    '!eNULL',
    '!EXPORT',
    '!DES',
    '!RC4',
    '!3DES',
    '!MD5',
    '!PSK'
}

ngx_config_tool.ssl_protocols = {
    'TLSv1',
    'TLSv1.1',
    'TLSv1.2'
}

ngx_config_tool.templates = {}

ngx_config_tool.templates.init_code = [=[package.path = '/usr/local/lib/lua/5.1/?.lua;'

        wsserver = require("websocket.server")
        json = require("cjson")]=]

ngx_config_tool.templates.main = [=[user ${nefsrv_user} ${nefsrv_group};

worker_processes ${worker_processes};

error_log  ${main_error_log} ${main_error_log_level};

pid logs/nefsrv.pid;

events
{
    worker_connections ${worker_connections};
}

http
{
    charset UTF-8;

    include mime.types;

    access_log  ${http_access_log};

    sendfile on;

    tcp_nodelay on;

    init_by_lua_block {
        ${init_code}
    }

    ${servers}
}]=]

ngx_config_tool.templates.public_srv = [=[server
    {
        listen ${public_srv_base_url} ssl http2 default;
        
        server_name '${public_server_name}';

        ssl_session_timeout 5m;

        ssl_prefer_server_ciphers on;

        ssl_protocols ${ssl_protocols};

        ssl_ciphers ${ciphersuite};

        keepalive_timeout 70;

        ssl_stapling ${public_srv_ssl_stapling};

        ssl_stapling_verify ${public_srv_ssl_stapling_verify};

        ssl_certificate ${public_srv_cert_file_path};

        ssl_certificate_key ${public_srv_key_file_path};

        ssl_dhparam ${public_srv_dhparam_file_path};

        set $l10_host '${l10_host}';

        set $l10_port ${l10_port};

        set $l10_get_limit ${l10_get_limit};

        set $l10_post_limit ${l10_post_limit};

        ${public_locations}
    }]=]

ngx_config_tool.templates.local_srv = [=[server
    {
        error_log ${local_srv_error_log} ${local_srv_error_log_level};

        server_name '${local_server_name}';

        listen ${local_srv_base_url};

        lua_need_request_body on;

        set $l10_host '${l10_host}';

        set $l10_port ${l10_port};

        ${local_locations}
    }]=]

ngx_config_tool.templates.servers = [=[${public_srv}

    ${local_srv}]=]

ngx_config_tool.templates.public_root_location = [=[location /
        {
            root ${public_root_location_path};
        }]=]

ngx_config_tool.templates.public_sc_location = [=[location ${public_sc_url}
        {
            set $route_token '${route_token}';

            lua_socket_pool_size ${public_sc_pool_size};

            default_type 'text/html';

            lua_code_cache ${public_sc_code_cache};

            content_by_lua_file '${public_sc_file_path}';
        }]=]

ngx_config_tool.templates.public_hub_location = [=[location ${public_hub_url}
        {
            access_by_lua_block {
                return ngx.exec('${public_sc_url}', {req = 'proxy', reverse_route = 'hub'})
            }
        }]=]

ngx_config_tool.templates.public_wssc_location = [=[location ${public_wssc_url}
        {
            lua_socket_pool_size ${public_wssc_pool_size};

            lua_socket_log_errors ${public_wssc_sock_log_errors};

            lua_check_client_abort on;
            
            content_by_lua_file '${public_wssc_file_path}';
        }]=]

ngx_config_tool.templates.public_locations = [=[${public_root_location}

        ${public_hub_location}

        ${public_wssc_location}

        ${public_sc_location}]=]

ngx_config_tool.templates.local_sc_location = [=[location ${local_sc_url}
        {
            set $nefsrv_secret '${nefsrv_secret}';

            set $server_secret '${server_secret}';

            lua_socket_pool_size ${local_sc_pool_size};

            default_type 'application/json';

            lua_code_cache ${local_sc_code_cache};

            content_by_lua_file '${local_sc_file_path}';
        }]=]

ngx_config_tool.templates.local_locations = [=[${local_sc_location}
]=]

ngx_config_tool.properties = {}

ngx_config_tool.properties.l10_config_file_path = ''
ngx_config_tool.properties.l10_project_file_path = ''
ngx_config_tool.properties.nefsrv_user = 'nef'
ngx_config_tool.properties.nefsrv_group = 'nef'
ngx_config_tool.properties.worker_processes = '2'
ngx_config_tool.properties.main_error_log = 'logs/error.log'
ngx_config_tool.properties.main_error_log_level = ''
ngx_config_tool.properties.worker_connections = '2048'
ngx_config_tool.properties.http_access_log = 'logs/access.log'
ngx_config_tool.properties.public_srv_base_url = ''
ngx_config_tool.properties.public_server_name = 'nefserver.public'
ngx_config_tool.properties.public_srv_ssl_stapling = 'off'
ngx_config_tool.properties.public_srv_ssl_stapling_verify = 'off'
ngx_config_tool.properties.public_srv_cert_file_path = ''
ngx_config_tool.properties.public_srv_key_file_path = ''
ngx_config_tool.properties.public_srv_dhparam_file_path = ''
ngx_config_tool.properties.l10_host = '127.0.0.1'
ngx_config_tool.properties.l10_port = '8193'
ngx_config_tool.properties.l10_get_limit = '1024'
ngx_config_tool.properties.l10_post_limit = '1024'
ngx_config_tool.properties.local_srv_error_log = 'logs/l10.log'
ngx_config_tool.properties.local_srv_error_log_level = 'debug'
ngx_config_tool.properties.local_server_name = 'nefserver.local'
ngx_config_tool.properties.local_srv_base_url = ''
ngx_config_tool.properties.public_root_location_path = 'scripts/root'
ngx_config_tool.properties.public_sc_url = ''
ngx_config_tool.properties.route_token = ''
ngx_config_tool.properties.public_sc_pool_size = '6'
ngx_config_tool.properties.public_sc_code_cache = 'on'
ngx_config_tool.properties.public_sc_file_path = 'scripts/scontroller_ngx_l5u.lua'
ngx_config_tool.properties.public_hub_url = '/hub'
ngx_config_tool.properties.public_wssc_url = '/websocket'
ngx_config_tool.properties.public_wssc_pool_size = '6'
ngx_config_tool.properties.public_wssc_sock_log_errors = 'off'
ngx_config_tool.properties.public_wssc_file_path = 'scripts/ws_server.lua'
ngx_config_tool.properties.local_sc_url = ''
ngx_config_tool.properties.nefsrv_secret = ''
ngx_config_tool.properties.server_secret = ''
ngx_config_tool.properties.local_sc_pool_size = '6'
ngx_config_tool.properties.local_sc_code_cache = 'on'
ngx_config_tool.properties.local_sc_file_path = 'scripts/scontroller_ngx_l7u.lua'

function ngx_config_tool:init()
    self.l10_config = config_tool:read(self.properties.l10_config_file_path)
    self.l10_project = project_tool:read(self.properties.l10_project_file_path)

    self.properties.l10_host = self.l10_config.host
    self.properties.l10_port = self.l10_config.port
    self.properties.public_srv_base_url = self.l10_project.base_url
    self.properties.local_srv_base_url = self.l10_config.host .. ':' .. tostring(self.l10_config.nefsrv_port)
    self.properties.public_sc_url = self.l10_project.scontroller_url
    self.properties.local_sc_url = self.l10_project.scontroller_url
    self.properties.route_token = self.l10_config.route_token
    self.properties.nefsrv_secret = self.l10_config.nefsrv_secret
    self.properties.server_secret = self.l10_config.server_secret
    self.properties.ssl_protocols = table.concat(self.ssl_protocols, " ")
    self.properties.ciphersuite = table.concat(self.ciphersuite, ":")
end

function ngx_config_tool:mk_config()
    self:init()

    local patch = {}

    patch.local_sc_location = {
        ['local_sc_url'] = self.properties.local_sc_url,
        ['nefsrv_secret'] = self.properties.nefsrv_secret,
        ['server_secret'] = self.properties.server_secret,
        ['local_sc_pool_size'] = self.properties.local_sc_pool_size,
        ['local_sc_code_cache'] = self.properties.local_sc_code_cache,
        ['local_sc_file_path'] = self.properties.local_sc_file_path
    }

    self.local_sc_location = lib_string:replace(self.templates.local_sc_location, patch.local_sc_location)

    patch.local_locations = {
        ['local_sc_location'] = self.local_sc_location
    }

    self.local_locations = lib_string:replace(self.templates.local_locations, patch.local_locations)

    patch.local_srv = {
        ['local_srv_error_log'] = self.properties.local_srv_error_log,
        ['local_srv_error_log_level'] = self.properties.local_srv_error_log_level,
        ['local_server_name'] = self.properties.local_server_name,
        ['local_srv_base_url'] = self.properties.local_srv_base_url,
        ['l10_host'] = self.properties.l10_host,
        ['l10_port'] = self.properties.l10_port,
        ['local_locations'] = self.local_locations
    }

    self.local_srv = lib_string:replace(self.templates.local_srv, patch.local_srv)

    patch.public_hub_location = {
        ['public_hub_url'] = self.properties.public_hub_url,
        ['public_sc_url'] = self.properties.public_sc_url,
    }

    self.public_hub_location = lib_string:replace(self.templates.public_hub_location, patch.public_hub_location)

    patch.public_wssc_location = {
        ['public_wssc_url'] = self.properties.public_wssc_url,
        ['public_wssc_pool_size'] = self.properties.public_wssc_pool_size,
        ['public_wssc_sock_log_errors'] = self.properties.public_wssc_sock_log_errors,
        ['public_wssc_file_path'] = self.properties.public_wssc_file_path
    }

    self.public_wssc_location = lib_string:replace(self.templates.public_wssc_location, patch.public_wssc_location)

    patch.public_sc_location = {
        ['public_sc_url'] = self.properties.public_sc_url,
        ['route_token'] = self.properties.route_token,
        ['public_sc_pool_size'] = self.properties.public_sc_pool_size,
        ['public_sc_code_cache'] = self.properties.public_sc_code_cache,
        ['public_sc_file_path'] = self.properties.public_sc_file_path
    }

    self.public_sc_location = lib_string:replace(self.templates.public_sc_location, patch.public_sc_location)

    patch.public_root_location = {
        ['public_root_location_path'] = self.properties.public_root_location_path
    }

    self.public_root_location = lib_string:replace(self.templates.public_root_location, patch.public_root_location)

    patch.public_locations = {
        ['public_root_location'] = self.public_root_location,
        ['public_hub_location'] = self.public_hub_location,
        ['public_wssc_location'] = self.public_wssc_location,
        ['public_sc_location'] = self.public_sc_location
    }

    self.public_locations = lib_string:replace(self.templates.public_locations, patch.public_locations)

    patch.public_srv = {
        ['public_srv_base_url'] = self.properties.public_srv_base_url,
        ['public_server_name'] = self.properties.public_server_name,
        ['ssl_protocols'] = self.properties.ssl_protocols,
        ['ciphersuite'] = self.properties.ciphersuite,
        ['public_srv_ssl_stapling'] = self.properties.public_srv_ssl_stapling,
        ['public_srv_ssl_stapling_verify'] = self.properties.public_srv_ssl_stapling_verify,
        ['public_srv_cert_file_path'] = self.properties.public_srv_cert_file_path,
        ['public_srv_key_file_path'] = self.properties.public_srv_key_file_path,
        ['public_srv_dhparam_file_path'] = self.properties.public_srv_dhparam_file_path,
        ['l10_host'] = self.properties.l10_host,
        ['l10_port'] = self.properties.l10_port,
        ['l10_get_limit'] = self.properties.l10_get_limit,
        ['l10_post_limit'] = self.properties.l10_post_limit,
        ['public_locations'] = self.public_locations
    }

    self.public_srv = lib_string:replace(self.templates.public_srv, patch.public_srv)

    patch.servers = {
        ['public_srv'] = self.public_srv,
        ['local_srv'] = self.local_srv
    }

    self.servers = lib_string:replace(self.templates.servers, patch.servers)

    patch.main = {
        ['nefsrv_user'] = self.properties.nefsrv_user,
        ['nefsrv_group'] = self.properties.nefsrv_group,
        ['worker_processes'] = self.properties.worker_processes,
        ['main_error_log'] = self.properties.main_error_log,
        ['main_error_log_level'] = self.properties.main_error_log_level,
        ['worker_connections'] = self.properties.worker_connections,
        ['http_access_log'] = self.properties.http_access_log,
        ['init_code'] = self.templates.init_code,
        ['servers'] = self.servers
    }

    return lib_string:replace(self.templates.main, patch.main)
end

function ngx_config_tool:write(config, config_name)
    if (not config or type(config) ~= 'string') then return false end

    if (not config_name or type(config_name) ~= 'string') then return false end

    local conf_fd = io.open(config_name, 'w')

    if (not conf_fd) then return false end

    conf_fd:write(config)
    conf_fd:close()

    return true
end

return ngx_config_tool