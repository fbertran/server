local Copas     = require "copas"
local Arguments = require "argparse"
local Colors    = require "ansicolors"
local Et        = require "etlua"
local Json      = require "cjson"
local Jwt       = require "jwt"
local Websocket = require "websocket"
local Time      = require "socket".gettime
local Util      = require "lapis.util"
local Config    = require "lapis.config".get ()
local Ltn12     = require "ltn12"
local CHttp     = require "copas.http"
local Http      = require "socket.http"

local file = io.tmpfile ()
local function print (s)
  file:write (s .. "\n")
  file:flush ()
end

local parser = Arguments () {
  name        = "cosy-editor",
  description = "collaborative editor for cosy models",
}
parser:option "--port" {
  description = "port",
  default     = "0",
  convert     = tonumber,
}
parser:argument "token" {
  description = "resource token",
}

local arguments = parser:parse ()

local decoded, err = Jwt.decode (arguments.token)
if not decoded then
  print (Colors (Et.render ("Failed to parse token: %{red}<%= error %>%{reset}", {
    error = err,
  })))
  os.exit (1)
end
local data = decoded.contents

function _G.string.split (s, delimiter)
  local result = {}
  for part in s:gmatch ("[^" .. delimiter .. "]+") do
    result [#result+1] = part
  end
  return result
end

local function request (http, url, options)
  local result = {}
  local headers = options.headers or {}
  if options.json then
    options.json = Json.encode (options.json)
    headers ["Content-length"] = #options.json
    headers ["Content-type"  ] = "application/json"
  end
  local _, status = http.request {
    url      = url,
    source   = options.json and Ltn12.source.string (options.json),
    sink     = Ltn12.sink.table (result),
    method   = options.method,
    headers  = headers,
  }
  if status ~= 200 then
    return nil, status
  end
  return Util.from_json (table.concat (result)), tonumber (status)
end

local last_access = Time ()
local server

local addserver = Copas.addserver
Copas.addserver = function (socket, f)
  local host, port = socket:getsockname ()
  addserver (socket, f)
  local url = "ws://" .. host .. ":" .. tostring (port) .. "/"
  Copas.addthread (function ()
    while true do
      Copas.sleep (1)
      if last_access + Config.editor.timeout <= Time () then
        server:close ()
        local _, status = request (CHttp, data.api .. "/editor", {
          method = "DELETE",
          headers = { Authorization = "Bearer " .. arguments.token }
        })
        assert (status == 204)
        return
      end
    end
  end)
  Copas.addthread (function ()
    local _, status = request (CHttp, data.api .. "/editor", {
      method  = "PATCH",
      headers = { Authorization = "Bearer " .. arguments.token},
      json    = {
        editor_url = url,
      }
    })
    assert (status == 204)
    print (Colors (Et.render ("%{blue}[<%= time %>]%{reset} Start editor for %{green}<%= api %>%{reset} at %{green}<%= url %>%{reset}.", {
      api  = data.api,
      time = os.date "%c",
      url  = url,
    })))
  end)
end

local function handler (ws)
  print (Colors (Et.render ("%{blue}[<%= time %>]%{reset} New connection for %{green}<%= resource %>%{reset}.", {
    resource = decoded.sub,
    time     = os.date "%c",
  })))
  ws:receive ()

  -- last_access = Time ()
  -- local message   = ws:receive ()
  -- local greetings = message and Util.from_json (message)
  -- if not greetings then
  --   return
  -- end
  -- local token = greetings.token
  -- token = Jwt.decode (token, {
  --   keys = {
  --     public = Config.auth0.client_secret
  --   }
  -- })
  -- if not token
  -- or token.resource ~= data.resource
  -- or not token.user
  -- or not token.permissions
  -- or not token.permissions.read then
  --   return
  -- end
  --
  -- while true do
  --   local message = ws:receive ()
  --   if message then
  --      ws:send (message)
  --   else
  --      ws:close ()
  --      return
  --   end
  -- end
end

local _, status = request (Http, data.api, {
  method  = "HEAD",
  headers = { Authorization = "Bearer " .. arguments.token},
})
if status == 204 then
  server = Websocket.server.copas.listen
  {
    port      = arguments.port,
    default   = handler,
    protocols = {
      cosy = handler,
    }
  }
  Copas.addserver = addserver
end

Copas.loop ()

print (Colors (Et.render ("%{blue}[<%= time %>]%{reset} Stop editor for %{green}<%= api %>.", {
  api  = data.api,
  time = os.date "%c",
})))
file:close ()
