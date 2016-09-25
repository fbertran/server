local Config = require "lapis.config".get ()
local Model  = require "cosy.server.model"
local Token  = require "cosy.server.token"
local Http   = require "cosy.server.http"
local Stop   = require "cosy.server.jobs.execution.stop"
local Qless  = require "resty.qless"
local Redis  = require "resty.redis"
local Et     = require "etlua"
local Mime   = require "mime"

local Start = {}

function Start.create (execution)
  local key   = "execution:start@" .. execution.path
  local redis = Redis:new ()
  assert (redis:connect (Config.redis.host, Config.redis.port))
  if redis:setnx (key, "...") == 0 then
    return -- already starting
  end
  local service = Model.services:create {
    path = execution.path,
  }
  execution:update ({
    service_id = service.id,
  }, { timestamp = false })
  local qless = Qless.new (Config.redis)
  local queue = qless.queues ["executions"]
  redis:set (key, queue:put ("cosy.server.jobs.execution.start", {
    id   = service.id,
    path = service.path,
  }, {
    jid = "execution@" .. tostring (service.id),
  }))
  redis:close ()
end

local function perform (execution, options)
  local project = execution:get_project ()
  local url     = "https://cloud.docker.com"
  local api     = url .. "/api/app/v1"
  local headers = {
    ["Authorization"] = "Basic " .. Mime.b64 (Config.docker.username .. ":" .. Config.docker.api_key),
  }
  -- Create service:
  local data = {
    resource = execution.resource,
    token    = Token (project.path, {}, math.huge),
  }
  local arguments = {}
  for key, value in pairs (data) do
    arguments [#arguments+1] = Et.render ("--<%- key %>=<%- value %>", {
      key   = key,
      value = value,
    })
  end
  local service, service_status = Http.json {
    url     = api .. "/service/",
    method  = "POST",
    headers = headers,
    body    = {
      image           = execution.image,
      run_command     = table.concat (arguments, " "),
      autorestart     = "OFF",
      autodestroy     = "ALWAYS",
      autoredeploy    = false,
      tags            = { Config.branch },
    },
  }
  if service_status ~= 201 then
    return
  end
  -- Start service:
  service = url .. service.resource_uri
  options.docker_url = service
  local _, started_status = Http.json {
    url     = service .. "start/",
    method  = "POST",
    headers = headers,
    timeout = 10, -- seconds
  }
  if started_status ~= 202 then
    return
  end
  local container
  do
    local result, status
    while true do
      result, status = Http.json {
        url     = service,
        method  = "GET",
        headers = headers,
      }
      if status == 200 and result.state:lower () ~= "starting" then
        container = result.containers and url .. result.containers [1]
        break
      else
        _G.ngx.sleep (1)
      end
    end
    if not container or result.state:lower () ~= "running" then
      return
    end
  end
  local _, container_status = Http.json {
    url     = container,
    method  = "GET",
    headers = headers,
  }
  if container_status ~= 200 then
    return
  end
  return true
end

function Start.perform (job)
  local redis = Redis:new ()
  assert (redis:connect (Config.redis.host, Config.redis.port))
  local execution = Model.executions:find {
    service_id = job.data.id,
  }
  local service  = execution:get_service ()
  local ok       = perform (execution, job.data)
  local key      = "execution:start@" .. execution.path
  service:update ({
    docker_url = job.data.docker_url,
    editor_url = job.data.editor_url,
  })
  if not ok then
    Stop.create (execution)
  end
  redis:del (key)
  redis:close ()
  return true
end

return Start
