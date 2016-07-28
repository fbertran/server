local M = {}

if _G.ngx then

  local Websocket = require "resty.websocket.client"

  function M.test (url, protocols)
    local client = Websocket:new {
      timeout = 5000, -- ms
    }
    local ok, err = client:connect (url, {
      protocols = protocols,
    })
    client:close ()
    return ok, err
  end

else

  local Websocket = require "websocket"

  function M.test (url, protocols)
    local client = Websocket.client.sync {
      timeout = 5, -- s
    }
    local ok, err = client:connect (url, protocols)
    client:close ()
    return ok, err
  end

end

return M
