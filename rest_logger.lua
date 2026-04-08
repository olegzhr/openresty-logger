local http  = require "resty.http"
local cjson = require "cjson.safe"

local _M = {}

local function nz(v)
    if v == nil or v == "" then
        return "-"
    end
    return v
end

local function build_log()
    return {
        request_uri          = nz(ngx.var.request_uri),
        request_id           = nz(ngx.var.request_id),
        request_method       = nz(ngx.req.get_method()),
        http_version         = nz(ngx.var.server_protocol),
        remote_addr          = nz(ngx.var.remote_addr),
        remote_user          = nz(ngx.var.remote_user),
        time_local           = nz(ngx.var.time_local),
        status               = ngx.status or 0,
        body_bytes_sent      = tonumber(ngx.var.body_bytes_sent) or 0,
        http_referer         = nz(ngx.var.http_referer),
        http_x_forwarded_for = nz(ngx.var.http_x_forwarded_for),
        http_x_real_ip       = nz(ngx.var.http_x_real_ip),
        http_host            = nz(ngx.var.http_host),
        http_user_agent      = nz(ngx.var.http_user_agent),
        http_authorization   = nz(ngx.var.http_authorization),
        http_accept_language = nz(ngx.var.http_accept_language),
        http_accept_encoding = nz(ngx.var.http_accept_encoding),
        http_connection      = nz(ngx.var.http_connection),
        http_cookie          = nz(ngx.var.http_cookie),
        request_body         = nz(ngx.var.request_body),
        response_body        = nz(ngx.var.resp_body)
    }
end

function _M.send(config)
    -- collect logs
    local log_data = build_log()

    -- timer for async sending
    local function async_send(premature, data)
        if premature then return end

        local json_log = cjson.encode(data)
        if not json_log then
            ngx.log(ngx.ERR, "rest_logger: failed to encode log")
            return
        end

        local encoded = ngx.encode_base64(json_log)
        local payload = {
            text_type   = "HTTP",
            text_sample = encoded,
            asset       = config.asset
        }

        local body = cjson.encode(payload)
        local httpc = http.new()
        httpc:set_timeout(1000)

        local res, err = httpc:request_uri(
            config.endpoint,
            {
                method  = "POST",
                body    = body,
                headers = {
                    ["Content-Type"]  = "application/json",
                    ["Authorization"] = config.token
                },
                keepalive = true
            }
        )

        if not res then
            ngx.log(ngx.ERR, "rest_logger: failed to send log: ", err)
            return
        end

        ngx.log(ngx.INFO, "rest_logger: packed log sent, status: ", res.status)
    end

    ngx.timer.at(0, async_send, log_data)
end

return _M