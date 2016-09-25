local Config    = require "lapis.config".get ()
local Websocket = require "resty.websocket.client"
local Model     = require "cosy.server.model"
local Token     = require "cosy.server.token"
local Http      = require "cosy.server.http"
local Hashid    = require "cosy.server.hashid"
local Check     = require "cosy.server.jobs.editor.check"
local Stop      = require "cosy.server.jobs.editor.stop"
local Qless     = require "resty.qless"
local Redis     = require "resty.redis"
local Et        = require "etlua"
local Mime      = require "mime"

local Start   = {}

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

function Start.create (resource)
  local key   = "editor:start@" .. resource.path
  local redis = Redis:new ()
  assert (redis:connect (Config.redis.host, Config.redis.port))
  if redis:setnx (key, "...") == 0 then
    return -- already starting
  end
  local service = Model.services:create {
    path = resource.path,
  }
  resource:update ({
    service_id = service.id,
  }, { timestamp = false })
  local qless = Qless.new (Config.redis)
  local queue = qless.queues ["editors"]
  redis:set (key, queue:put ("cosy.server.jobs.editor.start", {
    id   = service.id,
    path = service.path,
  }, {
    jid = "editor@" .. tostring (service.id),
  }))
  redis:close ()
end

local function perform (resource, options)
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
      options.editor_url = endpoint
      return true
    end
  end
  resource.endpoint = endpoint
end

function Start.perform (job)
  local redis = Redis:new ()
  assert (redis:connect (Config.redis.host, Config.redis.port))
  local resource = Model.resources:find {
    service_id = job.data.id,
  }
  local service  = resource:get_service ()
  local ok       = perform (resource, job.data)
  local key      = "editor:start@" .. resource.path
  service:update ({
    docker_url = job.data.docker_url,
    editor_url = job.data.editor_url,
  })
  if ok then
    Check.create (job.data)
  else
    Stop.create (resource)
  end
  redis:del (key)
  redis:close ()
  return true
end

return Start
