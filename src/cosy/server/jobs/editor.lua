local Config    = require "lapis.config".get ()
local Database  = require "lapis.db"
local Websocket = require "resty.websocket.client"
local Model     = require "cosy.server.model"
local Token     = require "cosy.server.token"
local Http      = require "cosy.server.http"
local Et        = require "etlua"
local Mime      = require "mime"

local Editor = {}

function Editor.cleanup (job)
  local headers = {
    ["Authorization"] = "Basic " .. Mime.b64 (Config.docker.username .. ":" .. Config.docker.api_key),
  }
  local mresource = Model.resources:find {
    id = job.data.resource,
  }
  local docker_url = job.data.docker_url or mresource.docker_url
  mresource:update ({
    editor_url = Database.NULL,
    docker_url = Database.NULL,
  }, { timestamp = false })
  if not docker_url then
    return
  end
  while true do
    local _, deleted_status = Http.json {
      url     = docker_url,
      method  = "DELETE",
      headers = headers,
    }
    if deleted_status == 202 or deleted_status == 404 then
      return
    end
    _G.ngx.sleep (1)
  end
end

function Editor.test (job)
  local client = Websocket:new {
    timeout = 500, -- ms
  }
  local ok, err = client:connect (job.data.editor_url)
  if ok then
    client:close ()
  end
  return ok, err
end

function Editor.perform (job)
  local url     = "https://cloud.docker.com"
  local api     = url .. "/api/app/v1"
  local headers = {
    ["Authorization"] = "Basic " .. Mime.b64 (Config.docker.username .. ":" .. Config.docker.api_key),
  }
  local mresource = Model.resources:find {
    id = job.data.resource,
  }
  local mproject  = mresource:get_project ()
  -- Create service:
  local data = {
    port     = 8080,
    timeout  = Config.editor.timeout,
    project  = job.data.project,
    resource = job.data.resource,
    token    = Token (mproject.url, {}, math.huge),
  }
  if Config.host ~= "localhost" then
    data.api = Et.render ("http://<%- host %>:<%- port %>", {
      host = Config.host,
      port = Config.port,
    })
  end
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
    error { status = service_status }
  end
  -- Start service:
  local resource = url .. service.resource_uri
  job.data.docker_url = resource
  job:heartbeat ()
  local _, started_status = Http.json {
    url     = resource .. "start/",
    method  = "POST",
    headers = headers,
    timeout = 10, -- seconds
  }
  if started_status ~= 202 then
    Editor.cleanup (job)
    return
  end
  local container
  do
    local result, status
    while true do
      job:heartbeat ()
      result, status = Http.json {
        url     = resource,
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
      Editor.cleanup (job)
      return
    end
  end
  job:heartbeat ()
  local info, container_status = Http.json {
    url     = container,
    method  = "GET",
    headers = headers,
  }
  if container_status ~= 200 then
    Editor.cleanup (job)
    return
  end
  -- Connect to editor:
  local endpoint = info.container_ports [1].endpoint_uri:gsub ("^http", "ws")
  job.data.editor_url = endpoint
  job:heartbeat ()
  local connected
  for _ = 1, 10 do
    _G.ngx.sleep (1)
    connected = Editor.test (job)
    if connected then
      break
    end
  end
  if not connected then
    Editor.cleanup (job)
    return
  end
  mresource:update ({
    docker_url = resource,
    editor_url = endpoint,
  }, { timestamp = false })
  -- Continue until editor has finished:
  while Editor.test (job) do
    job:heartbeat ()
    _G.ngx.sleep (math.min (job:ttl ()/2, Config.editor.timeout/2))
  end
  job:heartbeat ()
  Editor.cleanup (job)
  return true
end

return Editor
