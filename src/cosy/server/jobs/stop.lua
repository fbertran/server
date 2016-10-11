local Config   = require "lapis.config".get ()
local Database = require "lapis.db"
local Model    = require "cosy.server.model"
local Lock     = require "cosy.server.lock"

local Stop = {}

function Stop.perform (job)
  local lock = Lock:new (Config.redis)
  while not lock:lock (job.data.path) do
    _G.ngx.sleep (0.1)
  end
  local element = Model [job.data.collection]:find {
    service_id = job.data.service,
  }
  if element then
    element:update ({
      service_id = Database.NULL,
    }, { timestamp = false })
  end
  assert (lock:unlock (job.data.path))
end

return Stop
