local Ltn12 = require "ltn12"
local Util  = require "lapis.util"

local M = {}

if _G.ngx then

  local Http = require "resty.http"

  function M.json (options)
    assert (type (options) == "table")
    options.ssl_verify = false
    options.method = options.method or "GET"
    options.body   = options.body   and Util.to_json (options.body)
    options.headers ["Content-type"] = options.body and "application/json"
    options.headers ["Accept"      ] = "application/json"
    local client = Http.new ()
    client:set_timeout ((options.timeout or 5) * 1000) -- milliseconds
    local result = assert (client:request_uri (options.url, options))
    -- client:set_keepalive ()
    result.body = result.body
              and result.body ~= ""
              and Util.from_json (result.body)
               or result.body
    return result.body, result.status
  end

else

  local Http  = require "socket.http"
  local Https = require "ssl.https"

  function M.json (options)
    assert (type (options) == "table")
    local result = {}
    options.sink    = Ltn12.sink.table (result)
    options.method  = options.method  or "GET"
    options.body    = options.body    and Util.to_json (options.body)
    options.source  = options.body    and Ltn12.source.string (options.body)
    options.headers = options.headers or {}
    options.headers ["Content-length"] = options.body and #options.body or 0
    options.headers ["Content-type"  ] = options.body and "application/json"
    options.headers ["Accept"        ] = "application/json"
    local http = options.url:match "https://"
             and Https
              or Http
    local _, status, _, _ = http.request (options)
    result = #result ~= 0
         and Util.from_json (table.concat (result))
          or table.concat (result)
    return result, status
  end

end

return M
