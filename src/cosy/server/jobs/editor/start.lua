local Config    = require "lapis.config".get ()
local Websocket = require "resty.websocket.client"
local Model     = require "cosy.server.model"
local Token     = require "cosy.server.token"
local Http      = require "cosy.server.http"
local Hashid    = require "cosy.server.hashid"
local Qless     = require "resty.qless"
local Et        = require "etlua"
local Mime      = require "mime"

local Start = {}

local function test (resource)
  local client = Websocket:new {
    timeout = 500, -- ms
  }
  local ok, err = client:connect (resource.editor_url)
  if ok then
    client:close ()
  end
  return ok, err
end

function Start.create (resource)
  local qless = Qless.new (Config.redis)
  local queue = qless.queues ["editors"]
  local stop  = qless.jobs:get ("stop@" .. resource.url .. "/editor")
  queue:put ("cosy.server.jobs.editor.start", {
    resource = resource.id,
  }, {
    jid     = "start@" .. resource.url .. "/editor",
    depends = stop
          and "stop@"  .. resource.url .. "/editor",
  })
end

function Start.perform (job)
  local resource = Model.resources:find {
    id = job.data.resource,
  }
  local project  = resource:get_project ()
  local qless    = Qless.new (Config.redis)
  local queue    = qless.queues ["editors"]
  queue:put ("cosy.server.jobs.editor.stop", {
    resource = resource.id,
  }, {
    jid     = "stop@"  .. resource.url .. "/editor",
    depends = "start@" .. resource.url .. "/editor",
  })
  local ok, err = pcall (function ()
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
      token    = Token (project.url, {}, math.huge),
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
    job:heartbeat ()
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
      error {
        url    = api .. "/service/",
        method = "POST",
        status = service_status,
      }
    end
    -- Start service:
    service = url .. service.resource_uri
    resource:update ({
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
    local info, container_status = Http.json {
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
    -- Connect to editor:
    local endpoint = info.container_ports [1].endpoint_uri:gsub ("^http", "ws")
    resource:update ({
      editor_url = endpoint,
    }, { timestamp = false })
    job:heartbeat ()
    local connected
    for _ = 1, 10 do
      _G.ngx.sleep (1)
      connected = test (resource)
      if connected then
        break
      end
    end
    if not connected then
      error {
        connected = connected,
      }
    end
    -- Continue until editor has finished:
    while test (resource) do
      job:heartbeat ()
      _G.ngx.sleep (math.min (job:ttl ()/2, Config.editor.timeout/2))
    end
    job:heartbeat ()
  end)
  return ok or error (err)
end

return Start
