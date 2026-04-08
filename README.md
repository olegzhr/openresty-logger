# OpenResty module for API request logging

Lua module for OpenResty that logs API requests and responses to a remote endpoint with configurable parameters.

## Installation

### 1. Install Lua script

Copy the `rest_logger.lua` file to the OpenResty libraries directory:

```bash
sudo cp rest_logger.lua /usr/local/openresty/site/lualib/
```

### 2. Configure OpenResty

Edit the OpenResty configuration file (`/usr/local/openresty/nginx/conf/nginx.conf`) and add the logging settings:

```text
http {
    include       mime.types;
    default_type  application/octet-stream;

    lua_package_path "/usr/local/openresty/lualib/?.lua;;";
    lua_package_cpath "/usr/local/openresty/lualib/?.so;;";

    lua_need_request_body on;
    access_log off;

    init_by_lua_block {
        -- Configuration parameters for the logger
        SCE_CONFIG = {
            endpoint = "https://cs.alertflex.org/scr/api/v1/test/log",
            token    = "Bearer Auth-Key",
            asset    = "openresty-gateway"
        }
    }

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    server {
        listen 80;
        server_name _;
        return 301 https://$host$request_uri;
    }

    server {
        listen 443 ssl default_server;
        ssl_certificate /usr/local/openresty/nginx/cert/server.crt;
        ssl_certificate_key /usr/local/openresty/nginx/cert/server.key;

        set $resp_body "";

        # Configure your API endpoint
        location = /XXXXX {
            proxy_pass http://XXXXX;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            header_filter_by_lua_block {
                ngx.var.resp_body = ""
            }

            body_filter_by_lua_block {
                local chunk = ngx.arg[1]
                if not ngx.ctx.buffers then ngx.ctx.buffers = {} end
                if chunk and #chunk > 0 then
                    ngx.ctx.buffers[#ngx.ctx.buffers+1] = chunk
                end
                if ngx.arg[2] then
                    ngx.var.resp_body = string.sub(table.concat(ngx.ctx.buffers), 1, 2048)
                    ngx.ctx.buffers = nil
                end
            }

            log_by_lua_block {
                -- Call the logger to send data
                local logger = require "rest_logger"
                SCE_CONFIG.asset = "new_asset"  -- Can override the asset name if needed
                logger.send(SCE_CONFIG)
            }
        }
    }
}
```