local Arguments = require "argparse"
local Colors    = require "ansicolors"
local Et        = require "etlua"
local Redis     = require "redis"
local Jwt       = require "jwt"
local Copas     = require "copas.ev"
Copas:make_default ()
local Websocket = require "websocket"
local Time      = require "socket".gettime
local Util      = require "lapis.util"
local Config    = require "lapis.config".get ()
local Ltn12     = require "ltn12"
local Http      = require "socket.http"

local parser = Arguments () {
  name        = "cosy-editor",
  description = "editor for cosy models",
}
parser:option "--port" {
  description = "port",
  default     = "0",
  convert     = tonumber,
}
parser:option "--api" {
  description = "API url",
}
parser:option "--resource" {
  description = "resource identifier",
}
parser:option "--owner" {
  description = "owner token",
}

local arguments = parser:parse ()

if not arguments.api
or not arguments.resource
or not arguments.owner then
  print (parser:get_help ())
  os.exit (1)
end

local redis
do
  local ok, res = pcall (Redis.connect, Config.redis.host, Config.redis.port)
  if not ok then
    print (Colors (Et.render ("Runner failed to connect to redis instance %{green}<%= host %>%{reset}:%{green}<%= port %>%{reset}: %{red}<%= error %>%{reset}", {
      host     = Config.redis.host,
      port     = Config.redis.port,
      database = Config.redis.database,
      error    = res,
    })))
    os.exit (1)
  end
  redis = res
  ok, res = pcall (res.select, res, Config.redis.database)
  if not ok then
    print (Colors (Et.render ("Runner failed to switch to redis database %{green}<%= database %>%{reset}: %{red}<%= error %>%{reset}", {
      host     = Config.redis.host,
      port     = Config.redis.port,
      database = Config.redis.database,
      error    = res,
    })))
    os.exit (1)
  end
end
print (Colors (Et.render ("Runner listening on redis instance %{green}<%= host %>%{reset}:%{green}<%= port %>%{reset} database %{green}<%= database %>%{reset}.", {
  host     = Config.redis.host,
  port     = Config.redis.port,
  database = Config.redis.database,
})))

function _G.string.split (s, delimiter)
  local result = {}
  for part in s:gmatch ("[^" .. delimiter .. "]+") do
    result [#result+1] = part
  end
  return result
end

local function request (url, options)
  local result = {}
  local _, status = Http.request {
    url      = url,
    sink     = Ltn12.sink.table (result),
    method   = options.method,
    headers  = options.headers,
  }
  if status ~= 200 then
    return nil, status
  end
  return Util.from_json (table.concat (result)), status
end

local last_access = Time ()
local socket

Copas.addthread (function ()
  while true do
    Copas.sleep (Config.editor.timeout)
    if last_access + Config.editor.timeout <= Time () then
      redis:del ("resource:" .. arguments.resource)
      Copas.removeserver (socket)
      break
    end
  end
end)

local model = request (arguments.api, {
  method = "GET",
  headers = { Authorization = "Bearer " .. arguments.owner},
})
if not model then
  redis:del     ("resource:" .. arguments.resource)
  redis:publish ("resource:" .. arguments.resource, "")
  return
end

local addserver = Copas.addserver
Copas.addserver = function (s, f)
  socket = s
  local host, port = s:getsockname ()
  addserver (s, f)
  local url = "ws://" .. host .. ":" .. tostring (port)
  redis:set     ("resource:" .. arguments.resource, url)
  redis:publish ("resource:" .. arguments.resource, url)
  print (Colors (Et.render ("%{blue}[<%= time %>]%{reset} Start editor for %{green}<%= resource %>%{reset} at %{green}<%= url %>%{reset}.", {
    resource = arguments.resource,
    time     = os.date "%c",
    url      = url,
  })))
end

Websocket.server.copas.listen
{
  port      = arguments.port,
  protocols = {
    cosy = function (ws)
      local message   = ws:receive ()
      local greetings = message and Util.from_json (message)
      if not greetings then
        return
      end
      local token = greetings.token
      token = Jwt.decode (token, {
        keys = {
          public = Config.auth0.client_secret
        }
      })
      if not token
      or token.resource ~= arguments.resource
      or not token.user
      or not token.permissions
      or not token.permissions.read then
        return
      end

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
  }
}

Copas.loop ()

print (Colors (Et.render ("%{blue}[<%= time %>]%{reset} Stop editor for %{green}<%= resource %>%{reset}.", {
  resource = arguments.resource,
  time     = os.date "%c",
})))
