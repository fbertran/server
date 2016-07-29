local respond_to  = require "lapis.application".respond_to
local Config      = require "lapis.config".get ()
local Model       = require "cosy.server.model"
local Decorators  = require "cosy.server.decorators"
local Http        = require "cosy.server.http"
local Token       = require "cosy.server.token"
local Et          = require "etlua"
local Mime        = require "mime"

return function (app)

  require "cosy.server.projects.execution" (app)

  app:match ("/projects/:project/executions(/)", respond_to {
    HEAD    = Decorators.exists {}
           .. Decorators.can_read
           .. function ()
      return { status = 204 }
    end,
    OPTIONS = Decorators.exists {}
           .. Decorators.can_read
           .. function ()
      return { status = 204 }
    end,
    GET     = Decorators.exists {}
           .. Decorators.can_read
           .. function (self)
      return {
        status = 200,
        json   = self.project:get_executions () or {},
      }
    end,
    POST    = Decorators.exists {}
           .. Decorators.can_write
           .. function (self)
      local _, status = Http.json {
        url     = self.json.resource,
        method  = "HEAD",
        headers = {
          ["Authorization"] = "Bearer " .. self.token,
        }
      }
      if status ~= 204 then
        return { status = status }
      end
      local url     = "https://cloud.docker.com"
      local api     = url .. "/api/app/v1"
      local headers = {
        ["Authorization"] = "Basic " .. Mime.b64 (Config.docker.username .. ":" .. Config.docker.api_key),
      }
      -- Create service:
      local data = {
        resource = self.json.resource,
        token    = Token (Et.render ("/projects/<%- project %>", {
          project  = self.project.id,
        }), {}, math.huge),
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
          image           = self.json.image,
          run_command     = table.concat (arguments, " "),
          autorestart     = "OFF",
          autodestroy     = "ALWAYS",
          autoredeploy    = false,
        },
      }
      if service_status ~= 201 then
        return {
          status = status,
          json   = {
            reason = service,
          }
        }
      end
      -- Start service:
      local execution_url = url .. service.resource_uri
      local started, started_status = Http.json {
        url        = execution_url .. "start/",
        method     = "POST",
        headers    = headers,
        timeout    = 5, -- seconds
      }
      if started_status ~= 202 then
        return {
          status = status,
          json   = {
            reason = started,
          }
        }
      end
      local is_started
      for _ = 1, 10 do
        local running, running_status = Http.json {
          url     = execution_url,
          method  = "GET",
          headers = headers,
        }
        assert (running_status == 200)
        if running.state:lower () ~= "starting" then
          is_started = true
          break
        elseif _G.ngx and _G.ngx.sleep then
          _G.ngx.sleep (1)
        else
          os.execute "sleep 1"
        end
      end
      assert (is_started)
      local execution = Model.executions:create {
        project_id  = self.project.id,
        resource    = self.json.resource,
        image       = self.json.image,
        docker_url  = execution_url,
        name        = self.json.name,
        description = self.json.description,
      }
      return {
        status = 201,
        json   = execution,
      }
    end,
    DELETE  = Decorators.exists {}
           .. function ()
      return { status = 405 }
    end,
    PATCH   = Decorators.exists {}
           .. function ()
      return { status = 405 }
    end,
    PUT     = Decorators.exists {}
           .. function ()
      return { status = 405 }
    end,
  })

end
