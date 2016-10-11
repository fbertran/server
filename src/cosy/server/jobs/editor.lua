local Database  = require "lapis.db"
local Config    = require "lapis.config".get ()
local Websocket = require "resty.websocket.client"
local Qless     = require "resty.qless"
local Model     = require "cosy.server.model"
local Token     = require "cosy.server.token"
local Http      = require "cosy.server.http"
local Hashid    = require "cosy.server.hashid"
local Lock      = require "cosy.server.lock"
local Clean     = require "cosy.server.jobs.clean"
local Et        = require "etlua"
local Mime      = require "mime"

local Editor = {}

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

local function perform (resource)
  local project  = resource:get_project ()
  local url     = "https://cloud.docker.com"
  local api     = url .. "/api/app/v1"
  local headers = {
    ["Authorization"] = "Basic " .. Mime.b64 (Config.docker.username .. ":" .. Config.docker.api_key),
  }
  -- Create service:
  local data = {
    port     = 8080,
    timeout  = Config.editor.timeout,
    project  = Hashid.encode (resource.project_id),
    resource = Hashid.encode (resource.id),
    token    = Token (project.path, {}, math.huge),
  }
  -- FIXME
  -- data.api = Et.render ("http://<%- host %>:<%- port %>", {
  --   host = Config.host,
  --   port = Config.port,
  -- })
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
          published  = true,
        },
      },
    },
  }
  if service_status ~= 201 then
    return
  end
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
  local info, container_status = Http.json {
    url     = container,
    method  = "GET",
    headers = headers,
  }
  if container_status ~= 200 then
    return
  end
  -- Connect to editor:
  local endpoint = info.container_ports [1].endpoint_uri:gsub ("^http", "ws")
  for _ = 1, 30 do
    _G.ngx.sleep (1)
    local connected = test (endpoint)
    if connected then
      resource:get_service ():update {
        editor_url = endpoint,
      }
      return true
    end
  end
  resource.endpoint = endpoint
end

function Editor.perform (job)
  local resource
  local service = assert (Model.services:find {
    id = job.data.service,
  })
  if not pcall (function ()
    resource = assert (Model.resources:find {
      id = job.data.resource,
    })
    assert (resource.service_id == service.id)
    assert (perform (resource))
  end) then
    if resource and resource.service_id == service.id then
      resource:update ({
        service_id = Database.NULL,
      }, { timestamp = false })
    end
  end
end

return Editor
