local Config   = require "lapis.config".get ()
local Database = require "lapis.db"
local Model    = require "cosy.server.model"
local Http     = require "cosy.server.http"
local Qless    = require "resty.qless"
local Mime     = require "mime"

local Stop = {}

function Stop.create (resource)
  local qless = Qless.new (Config.redis)
  local queue = qless.queues ["editors"]
  local start = qless.jobs:get ("start@" .. resource.path .. "/editor")
  if start then
    start:cancel ()
  end
  queue:put ("cosy.server.jobs.editor.stop", {
    resource = resource.id,
  }, {
    jid = "stop@" .. resource.path .. "/editor",
  })
end

function Stop.perform (job)
  local headers = {
    ["Authorization"] = "Basic " .. Mime.b64 (Config.docker.username .. ":" .. Config.docker.api_key),
  }
  local resource = Model.resources:find {
    id = job.data.resource,
  }
  resource:update ({
    editor_url = Database.NULL,
  }, { timestamp = false })
  if resource.docker_url then
    while true do
      local _, deleted_status = Http.json {
        url     = resource.docker_url,
        method  = "DELETE",
        headers = headers,
      }
      if deleted_status == 202 or deleted_status == 404 then
        break
      end
      _G.ngx.sleep (1)
    end
  end
  resource:update ({
    docker_url = Database.NULL,
  }, { timestamp = false })
  return true
end

return Stop
