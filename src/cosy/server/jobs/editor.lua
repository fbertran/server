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
local Url      = require "socket.url"

local Editor = {}

function Editor.start (resource)
  Clean.create ()
  local lock = Lock:new (Config.redis)
  assert (lock:lock (resource.path))
  resource:refresh "service_id"
  if not resource.service_id then
    local service = Model.services:create {
      path = resource.path,
    }
    resource:update ({
      service_id = service.id,
    }, { timestamp = false })
    local qless = Qless.new (Config.redis)
    local queue = qless.queues ["cosy"]
    local jid   = queue:put ("cosy.server.jobs.editor", {
      path     = resource.path,
      resource = resource.id,
      service  = service.id,
      url      = Config.url .. resource.path
    })
    service:update {
      qless_job = jid,
    }
  end
  assert (lock:unlock (resource.path))
end

function Editor.stop (resource)
  local lock = Lock:new (Config.redis)
  assert (lock:lock (resource.path))
  resource:refresh "service_id"
  if resource.service_id then
    local service = resource:get_service ()
    local qless   = Qless.new (Config.redis)
    local queue   = qless.queues ["cosy"]
    queue:put ("cosy.server.jobs.stop", {
      collection = "resources",
      path       = resource.path,
      service    = resource.service_id,
    }, { depends = { service.qless_job } })
  end
  assert (lock:unlock (resource.path))
end

local function perform (resource, job)
  local project  = resource:get_project ()
  local url     = "https://cloud.docker.com"
  local api     = url .. "/api/app/v1"
  local headers = {
    ["Authorization"] = "Basic " .. Mime.b64 (Config.docker.username .. ":" .. Config.docker.api_key),
  }
  -- Create service:
  local data = {
    token    = Token (project.path, {}, math.huge),
    resource = job.data.url,
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
      image           = Et.render ("cosyverif/editor:<%- branch %>", {
        branch = Config.branch,
      }),
      run_command     = table.concat (arguments, " "),
      autorestart     = "OFF",
      autodestroy     = "ALWAYS",
      autoredeploy    = false,
      tags            = { Config.branch },
      container_ports = {
        { protocol   = "tcp",
          inner_port = 8080,
          outer_port = 80,
          published  = true,
        },
      },
    },
  }
  assert (service_status == 201, service_status)
  -- Editor service:
  service = url .. service.resource_uri
  resource:get_service ():update {
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
    local result, status
    while true do
      result, status = Http.json {
        url     = service,
        method  = "GET",
        headers = headers,
      }
      if status == 200 and result.state:lower () ~= "starting" then
        resource:get_service ():update {
          editor_url = Url.build {
            scheme = "http",
            host   = result.public_dns,
          }
        }
        return
      else
        _G.ngx.sleep (1)
      end
    end
  end
end

function Editor.perform (job)
  local resource
  local service = assert (Model.services:find {
    id = job.data.service,
  })
  if not xpcall (function ()
    resource = assert (Model.resources:find {
      id = job.data.resource,
    })
    assert (resource.service_id == service.id)
    perform (resource, job)
  end, function (err)
    print (err, debug.traceback ())
  end) and resource then
    local lock = Lock:new (Config.redis)
    assert (lock:lock (resource.path))
    resource:refresh ()
    if resource.service_id == service.id then
      resource:update ({
        service_id = Database.NULL,
      }, { timestamp = false })
    end
    assert (lock:unlock (resource.path))
  end
end

return Editor
