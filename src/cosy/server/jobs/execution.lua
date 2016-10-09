local Database = require "lapis.db"
local Config   = require "lapis.config".get ()
local Lock     = require "resty.lock"
local Qless    = require "resty.qless"
local Model    = require "cosy.server.model"
local Token    = require "cosy.server.token"
local Http     = require "cosy.server.http"
local Clean    = require "cosy.server.jobs.clean"
local Et       = require "etlua"
local Mime     = require "mime"

local Execution = {}

function Execution.start (execution)
  Clean.create ()
  local lock = Lock:new ("locks", {
    timeout = 1,    -- seconds
    step    = 0.01, -- seconds
  })
  assert (lock:lock (execution.path))
  execution:refresh "service_id"
  if not execution.service_id then
    local service = Model.services:create {
      path = execution.path,
    }
    execution:update ({
      service_id = service.id,
    }, { timestamp = false })
    local qless = Qless.new (Config.redis)
    local queue = qless.queues ["cosy"]
    local jid   = queue:put ("cosy.server.jobs.editor", {
      path      = execution.path,
      execution = execution.id,
      service   = service.id,
    })
    service:update {
      qless_job = jid,
    }
  end
  assert (lock:unlock ())
end

function Execution.stop (execution)
  local lock = Lock:new ("locks", {
    timeout = 1,    -- seconds
    step    = 0.01, -- seconds
  })
  assert (lock:lock (execution.path))
  execution:refresh "service_id"
  if execution.service_id then
    local service = execution:get_service ()
    local qless   = Qless.new (Config.redis)
    local queue   = qless.queues ["cosy"]
    queue:put ("cosy.server.jobs.stop", {
      collection = "executions",
      path       = execution.path,
      service    = execution.service_id,
    }, { depends = { service.qless_job } })
  end
  assert (lock:unlock ())
end

local function perform (execution)
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
  -- Execution service:
  service = url .. service.resource_uri
  execution:get_service ():update {
    docker_url = service,
  }
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

function Execution.perform (job)
  local execution
  local service = assert (Model.services:find {
    id = job.data.service,
  })
  if not pcall (function ()
    execution = assert (Model.executions:find {
      id = job.data.execution,
    })
    assert (execution.service_id == service.id)
    assert (perform (execution))
  end) then
    if execution and execution.service_id == service.id then
      execution:update ({
        service_id = Database.NULL,
      }, { timestamp = false })
    end
  end
end

return Execution
