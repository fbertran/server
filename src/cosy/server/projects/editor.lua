local Config      = require "lapis.config".get ()
local Database    = require "lapis.db"
local respond_to  = require "lapis.application".respond_to
local Decorators  = require "cosy.server.decorators"
local Token       = require "cosy.server.token"
local Http        = require "cosy.server.http"
local Ws          = require "cosy.server.ws"
local Docker      = require "cosy.server.docker"
local Et          = require "etlua"
local Mime        = require "mime"

return function (app)

  app:match ("/projects/:project/resources/:resource/editor", respond_to {
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
      if self.resource.editor_url then
        if Ws.test (self.resource.editor_url, "cosy") then
          return { redirect_to = self.resource.editor_url }
        end
      end
      local url     = "https://cloud.docker.com"
      local api     = url .. "/api/app/v1"
      local headers = {
        ["Authorization"] = "Basic " .. Mime.b64 (Config.docker.username .. ":" .. Config.docker.api_key),
      }
      if self.resource.docker_url then
        Docker.delete (self.resource.docker_url)
        self.resource:update ({
          editor_url = Database.NULL,
          docker_url = Database.NULL,
        }, { timestamp = false })
      end
      -- Create service:
      local data = {
        port     = 8080,
        timeout  = Config.editor.timeout,
        project  = self.project.id,
        resource = self.resource.id,
        token    = Token (Et.render ("/projects/<%- project %>", {
          project  = self.project.id,
        }), {}, math.huge),
      }
      if Config.hostname ~= "localhost" then
        data.api = Et.render ("http://<%- host %>:<%- port %>", {
          host = Config.hostname,
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
          container_ports = {
            { protocol   = "tcp",
              inner_port = 8080,
              published  = true,
            },
          },
        },
      }
      if service_status ~= 201 then
        return { status = 503 }
      end
      -- Start service:
      local resource = url .. service.resource_uri
      local _, started_status = Http.json {
        url        = resource .. "start/",
        method     = "POST",
        headers    = headers,
        timeout    = 5, -- seconds
      }
      if started_status ~= 202 then
        Docker.delete (resource)
        return { status = 503 }
      end
      local container
      do
        local result, status
        while true do
          result, status = Http.json {
            url     = resource,
            method  = "GET",
            headers = headers,
          }
          if status == 200 and result.state:lower () ~= "starting" then
            container = result.containers and url .. result.containers [1]
            break
          elseif _G.ngx and _G.ngx.sleep then
            _G.ngx.sleep (1)
          else
            os.execute "sleep 1"
          end
        end
        if not container or result.state:lower () ~= "running" then
          Docker.delete (resource)
          return { status = 503 }
        end
      end
      local info, container_status = Http.json {
        url     = container,
        method  = "GET",
        headers = headers,
      }
      if container_status ~= 200 then
        Docker.delete (resource)
        return { status = 503 }
      end
      local endpoint = info.container_ports [1].endpoint_uri:gsub ("^http", "ws")
      local i = 0
      while true do
        i = i+1
        local connected = Ws.test (endpoint, "cosy")
        if connected then
          break
        elseif i >= 10 then
          Docker.delete (resource)
          return { status = 503 }
        elseif _G.ngx and _G.ngx.sleep then
          _G.ngx.sleep (1)
        else
          os.execute "sleep 1"
        end
      end
      while true do
        Database.query [[BEGIN]]
        self.resource:refresh ("editor_url", "docker_url")
        if self.resource.editor_url then
          Database.query [[ROLLBACK]]
          Docker.delete (resource)
          if Ws.test (self.resource.editor_url, "cosy") then
            return { redirect_to = self.resource.editor_url }
          else
            return { status = 409 }
          end
        end
        self.resource:update {
          docker_url = resource,
          editor_url = endpoint,
        }
        if Database.query [[COMMIT]] then
          break
        end
      end
      return { redirect_to = self.resource.editor_url }
    end,
    DELETE  = Decorators.exists {}
           .. Decorators.is_authentified
           .. function (self)
      if self.identity.type   ~= "project"
      or self.authentified.id ~= self.project.id then
        return { status = 403 }
      end
      if self.resource.editor_url then
        Docker.delete (self.resource.docker_url)
        self.resource:update ({
          editor_url = Database.NULL,
          docker_url = Database.NULL,
        }, { timestamp = false })
      end
      return { status = 204 }
    end,
    PATCH   = Decorators.exists {}
           .. function ()
      return { status = 405 }
    end,
    POST    = Decorators.exists {}
           .. function ()
      return { status = 405 }
    end,
    PUT     = Decorators.exists {}
           .. function ()
      return { status = 405 }
    end,
  })

end
