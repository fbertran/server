local Arguments = require "argparse"
local Colors    = require "ansicolors"
local Et        = require "etlua"
local Config    = require "lapis.config".get ()
local Util        = require "lapis.util"
local Redis     = require "redis"

local prefix
do
  local path = package.searchpath ("cosy.check.cli", package.path)
  local parts = {}
  for part in path:gmatch "[^/]+" do
    parts [#parts+1] = part
  end
  for _ = 1, 6 do
    parts [#parts] = nil
  end
  prefix = (path:find "^/" and "/" or "") .. table.concat (parts, "/")
end


local parser = Arguments () {
  name        = "cosy-taskqueue",
  description = "task queue for cosy editors and tools",
}
parser:flag "--quit" {
  description = "quit",
}

local arguments = parser:parse ()

function _G.string.split (s, delimiter)
  local result = {}
  for part in s:gmatch ("[^" .. delimiter .. "]+") do
    result [#result+1] = part
  end
  return result
end

local channels = {
  "control",
  "resource:edit",
}

local redis = {
  pub = true,
  set = true,
}

for key in pairs (redis) do
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
  redis [key] = res
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

if arguments.quit then
  redis.pub:publish ("control", "quit")
  os.exit (0)
end

for message in redis.pub:pubsub { subscribe = channels } do
  if message.kind == "message" then
    if message.channel == "control" then
      if message.payload == 'quit' then
        print (Colors (Et.render ("%{blue}[<%= time %>]%{reset} Received order to quit.", {
          time     = os.date "%c"
        })))
        break
      end
    elseif message.channel == "resource:edit" then
      local data = Util.from_json (message.payload)
      os.execute (Et.render ([[
        "<%= prefix %>/bin/cosy-editor" \
          --api="<%= api %>" \
          --owner="<%= owner %>" \
          --resource="<%= resource %>" &
      ]], {
        prefix   = prefix,
        api      = data.api,
        resource = data.resource,
        owner    = data.owner,
      }))
    end
  end
end
