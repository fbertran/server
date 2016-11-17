local Database = require "lapis.db"
local Config   = require "lapis.config".get ()
local Qless    = require "resty.qless"
local Model    = require "cosy.server.model"
local Token    = require "cosy.server.token"
local Http     = require "cosy.server.http"
local Lock     = require "cosy.server.lock"
local Clean    = require "cosy.server.jobs.clean"
local Et       = require "etlua"
local Mime     = require "mime"

local Execution = {}

function Execution.start (execution)
  Clean.create ()
  local lock = Lock:new (Config.redis)
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
    local jid   = queue:put ("cosy.server.jobs.execution", {
      path      = execution.path,
      execution = execution.id,
      service   = service.id,
    })
    service:update {
      qless_job = jid,
    }
  end
  assert (lock:unlock (execution.path))
end

function Execution.stop (execution)
  local lock = Lock:new (Config.redis)
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
  assert (lock:unlock (execution.path))
end

local function perform (execution)
  local resource = execution:get_resource ()
  local project  = resource:get_project ()
  local url      = "https://cloud.docker.com"
  local api      = url .. "/api/app/v1"
  local headers  = {
    ["Authorization"] = "Basic " .. Mime.b64 (Config.docker.username .. ":" .. Config.docker.api_key),
  }
  -- Create service:
  local data = {
    resource = resource.path,
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
    },
  }
  assert (service_status == 201, service_status)
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
  assert (started_status == 202, started_status)
  do
    while true do
      local result, status = Http.json {
        url     = service,
        method  = "GET",
        headers = headers,
      }
      assert (status == 200, status)
      if status == 200 and result.state:lower () ~= "starting" then
        execution:get_service ():update {
          launched = true,
        }
        return
      else
        _G.ngx.sleep (1)
      end
    end
  end
end

function Execution.perform (job)
  local execution
  local service = assert (Model.services:find {
    id = job.data.service,
  })
  if not xpcall (function ()
    execution = assert (Model.executions:find {
      id = job.data.execution,
    })
    assert (execution.service_id == service.id)
    perform (execution)
  end, function (err)
    print (err, debug.traceback ())
  end) and execution then
    local lock = Lock:new (Config.redis)
    assert (lock:lock (execution.path))
    execution:refresh ()
    if execution.service_id == service.id then
      execution:update ({
        service_id = Database.NULL,
      }, { timestamp = false })
    end
    assert (lock:unlock (execution.path))
    error "execution failed"
  end
  return true
end

return Execution
