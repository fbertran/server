local Config   = require "lapis.config".get ()
local Database = require "lapis.db"
local Model    = require "cosy.server.model"
local Http     = require "cosy.server.http"
local Qless    = require "resty.qless"
local Mime     = require "mime"

local Stop = {}

function Stop.create (execution)
  local qless = Qless.new (Config.redis)
  local queue = qless.queues ["executions"]
  local start = qless.jobs:get ("start@" .. execution.url)
  if start then
    start:cancel ()
  end
  queue:put ("cosy.server.jobs.execution.stop", {
    execution = execution.id,
  }, {
    jid = "stop@" .. execution.url,
  })
end

function Stop.perform (job)
  local headers = {
    ["Authorization"] = "Basic " .. Mime.b64 (Config.docker.username .. ":" .. Config.docker.api_key),
  }
  local execution = Model.executions:find {
    id = job.data.execution,
  }
  if execution.docker_url then
    while true do
      local _, deleted_status = Http.json {
        url     = execution.docker_url,
        method  = "DELETE",
        headers = headers,
      }
      if deleted_status == 202 or deleted_status == 404 then
        break
      end
      _G.ngx.sleep (1)
    end
  end
  execution:update ({
    docker_url = Database.NULL,
  }, { timestamp = false })
  return true
end

return Stop
