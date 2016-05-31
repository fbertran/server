local Arguments = require "argparse"
local Colors    = require "ansicolors"
local Et        = require "etlua"
local Config    = require "lapis.config".get ()
local Util      = require "lapis.util"
local Redis     = require "redis"
local channels  = require "cosy.taskqueue.channels"

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
  redis.pub:publish ("control", Util.to_json {
    control = "quit",
  })
  os.exit (0)
end

local channels_list = {}
for _, channel in pairs (channels) do
  channels_list [#channels_list+1] = channel
end

for message in redis.pub:pubsub { subscribe = channels_list } do
  if message.kind == "message" then
    if message.channel == channels.control then
      local data = Util.from_json (message.payload)
      if data.control == "quit" then
        print (Colors (Et.render ("%{blue}[<%= time %>]%{reset} Received order to quit.", {
          time = os.date "%c"
        })))
        break
      end
    elseif message.channel == channels.edition then
      local data = Util.from_json (message.payload)
      os.execute (Et.render ([[ "<%= prefix %>/bin/cosy-editor" "<%= token %>" ]], {
        prefix = prefix,
        token  = data.token,
      }))
    end
  end
end
