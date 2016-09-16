local Config    = require "lapis.config".get ()
local Database  = require "lapis.db"
local Model     = require "cosy.server.model"
local Token     = require "cosy.server.token"
local Http      = require "cosy.server.http"
local Et        = require "etlua"
local Mime      = require "mime"

local Execution = {}

function Execution.cleanup (job)
  local headers = {
    ["Authorization"] = "Basic " .. Mime.b64 (Config.docker.username .. ":" .. Config.docker.api_key),
  }
  local mexecution = Model.executions:find {
    id = job.data.execution,
  }
  local docker_url = job.data.docker_url or mexecution.docker_url
  mexecution:update ({
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

function Execution.perform (job)
  local url     = "https://cloud.docker.com"
  local api     = url .. "/api/app/v1"
  local headers = {
    ["Authorization"] = "Basic " .. Mime.b64 (Config.docker.username .. ":" .. Config.docker.api_key),
  }
  local mexecution = Model.executions:find {
    id = job.data.execution,
  }
  local mproject   = mexecution:get_project ()
  -- Create service:
  local data = {
    resource = mexecution.resource,
    token    = Token (mproject.url, {}, math.huge),
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
      image        = mexecution.image,
      run_command  = table.concat (arguments, " "),
      autorestart  = "OFF",
      autodestroy  = "ALWAYS",
      autoredeploy = false,
      tags         = { Config.branch },
    },
  }
  if service_status ~= 201 then
    error { status = service_status }
  end
  -- Start service:
  local execution = url .. service.resource_uri
  job.data.docker_url = execution
  job:heartbeat ()
  local _, started_status = Http.json {
    url     = execution .. "start/",
    method  = "POST",
    headers = headers,
    timeout = 10, -- seconds
  }
  if started_status ~= 202 then
    Execution.cleanup (job)
    return
  end
  local container
  do
    local result, status
    while true do
      job:heartbeat ()
      result, status = Http.json {
        url     = execution,
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
      Execution.cleanup (job)
      return
    end
  end
  job:heartbeat ()
  local _, container_status = Http.json {
    url     = container,
    method  = "GET",
    headers = headers,
  }
  if container_status ~= 200 then
    Execution.cleanup (job)
    return
  end
  mexecution:update ({
    docker_url = execution,
  }, { timestamp = false })
  -- Continue until execution has finished:
  while true do
    job:heartbeat ()
    local result, status = Http.json {
      url     = execution,
      method  = "GET",
      headers = headers,
    }
    if status == 200 and result.state:lower () ~= "running" then
      break
    elseif status == 404 then
      break
    else
      _G.ngx.sleep (1)
    end
  end
  job:heartbeat ()
  Execution.cleanup (job)
  return true
end

return Execution
