local Config    = require "lapis.config".get ()
local Websocket = require "resty.websocket.client"
local Stop      = require "cosy.server.jobs.editor.stop"
local Qless     = require "resty.qless"
local Redis     = require "resty.redis"

local Check = {}

local function test (editor)
  local client = Websocket:new {
    timeout = 500, -- ms
  }
  local ok, err = client:connect (editor)
  if ok then
    client:close ()
  end
  return ok, err
end

function Check.create (options)
  local key   = "editor:check@" .. tostring (options.id)
  local redis = Redis:new ()
  assert (redis:connect (Config.redis.host, Config.redis.port))
  if redis:setnx (key, "...") == 0 then
    return -- already starting
  end
  local qless = Qless.new (Config.redis)
  local queue = qless.queues ["editors"]
  redis:set (key, queue:put ("cosy.server.jobs.editor.check", {
    id         = options.id,
    path       = options.path,
    docker_url = options.docker_url,
    editor_url = options.editor_url,
  }))
  redis:close ()
end

function Check.perform (job)
  repeat
    _G.ngx.sleep (15)
  until not test (job.data.editor_url)
  Stop.create (nil, job.data)
  local redis = Redis:new ()
  assert (redis:connect (Config.redis.host, Config.redis.port))
  redis:del ("editor:check@" .. tostring (job.data.id))
  redis:close ()
  return true
end

return Check
