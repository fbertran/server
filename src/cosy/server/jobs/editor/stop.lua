local Config   = require "lapis.config".get ()
local Database = require "lapis.db"
local Model    = require "cosy.server.model"
local Http     = require "cosy.server.http"
local Qless    = require "resty.qless"
local Redis    = require "resty.redis"
local Mime     = require "mime"

local Stop = {}

function Stop.create (resource, data)
  local service
  if resource then
    service = resource:get_service ()
  else
    assert (data)
    resource = Model.resources:find { service_id = data.id }
    service  = Model.services :find { id         = data.id }
  end
  if not service then
    return
  end
  local key   = "editor:stop@" .. tostring (service.id)
  local redis = Redis:new ()
  assert (redis:connect (Config.redis.host, Config.redis.port))
  if redis:setnx (key, "...") == 0 then
    return -- already stopping
  end
  if resource and resource.service_id == service.id then
    resource:update ({
      service_id = Database.NULL,
    }, { timestamp = false })
  end
  local qless = Qless.new (Config.redis)
  local queue = qless.queues ["editors"]
  local start = qless.jobs:get ("editor@" .. tostring (service.id))
  redis:set (key, queue:put ("cosy.server.jobs.editor.stop", {
    id         = service.id,
    path       = service.path,
    docker_url = service.docker_url,
    editor_url = service.editor_url,
  }, {
    depends = start and { start.jid } or nil,
  }))
  redis:close ()
end

function Stop.perform (job)
  local headers = {
    ["Authorization"] = "Basic " .. Mime.b64 (Config.docker.username .. ":" .. Config.docker.api_key),
  }
  local _, deleted_status = Http.json {
    url     = job.data.docker_url,
    method  = "DELETE",
    headers = headers,
  }
  assert (deleted_status == 202 or deleted_status == 404)
  Model.services:find {
    id = job.data.id,
  }:delete ()
  local redis = Redis:new ()
  assert (redis:connect (Config.redis.host, Config.redis.port))
  redis:del ("editor:stop@" .. tostring (job.data.id))
  redis:close ()
  return true
end

return Stop
