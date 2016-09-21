local Config = require "lapis.config".get ()
local Model  = require "cosy.server.model"
local Token  = require "cosy.server.token"
local Http   = require "cosy.server.http"
local Qless  = require "resty.qless"
local Et     = require "etlua"
local Mime   = require "mime"

local Start = {}

function Start.create (execution)
  local qless = Qless.new (Config.redis)
  local queue = qless.queues ["executions"]
  local stop  = qless.jobs:get ("stop@" .. execution.path)
  queue:put ("cosy.server.jobs.execution.start", {
    execution = execution.id,
  }, {
    jid     = "start@" .. execution.path,
    depends = stop
          and "stop@"  .. execution.path,
  })
end

function Start.perform (job)
  local execution = Model.executions:find {
    id = job.data.execution,
  }
  local project  = execution:get_project ()
  local ok, err = pcall (function ()
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
    job:heartbeat ()
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
      error {
        url    = api .. "/service/",
        method = "POST",
        status = service_status,
      }
    end
    -- Start service:
    service = url .. service.resource_uri
    execution:update ({
      docker_url = service,
    }, { timestamp = false })
    job:heartbeat ()
    local _, started_status = Http.json {
      url     = service .. "start/",
      method  = "POST",
      headers = headers,
      timeout = 10, -- seconds
    }
    if started_status ~= 202 then
      error {
        url    = service .. "start/",
        method = "POST",
        status = started_status,
      }
    end
    local container
    do
      local result, status
      while true do
        job:heartbeat ()
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
        error {
          url    = service,
          method = "GET",
          status = status,
        }
      end
    end
    job:heartbeat ()
    local _, container_status = Http.json {
      url     = container,
      method  = "GET",
      headers = headers,
    }
    if container_status ~= 200 then
      error {
        url    = container,
        method = "GET",
        status = container_status,
      }
    end
  end)
  return ok or error (err)
end

return Start
