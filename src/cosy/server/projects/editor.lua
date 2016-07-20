local Config      = require "lapis.config".get ()
local Database    = require "lapis.db"
local respond_to  = require "lapis.application".respond_to
local Decorators  = require "cosy.server.decorators"
local Token       = require "cosy.server.token"
local Http        = require "cosy.server.http"
local Et          = require "etlua"
local Mime        = require "mime"
local _, Wsclient = pcall (require, "resty.websocket.client")

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
      local url     = "https://cloud.docker.com"
      local api     = url .. "/api/app/v1"
      local headers = {
        ["Authorization"] = "Basic " .. Mime.b64 (Config.docker.username .. ":" .. Config.docker.api_key),
        ["Accept"       ] = "application/json",
        ["Content-type" ] = "application/json",
      }
      if self.resource.editor_url then
        local client = Wsclient:new ()
        if client:connect (self.resource.editor_url, {
          protocols = "echo",
        }) then
          client:close ()
          return {
            redirect_to = self.resource.editor_url:gsub ("^http", "ws"),
          }
        end
      end
      if self.resource.docker_url then
        local _, status = Http.request {
          url     = self.resource.docker_url,
          method  = "DELETE",
          headers = headers,
        }
        assert (status == 202)
        self.resource:update ({
          editor_url = Database.NULL,
          docker_url = Database.NULL,
        }, { timestamp = false })
      end
      -- Create service:
      local service, service_status = Http.request {
        url     = api .. "/service/",
        method  = "POST",
        headers = headers,
        body    = {
          image           = "dataferret/websocket-echo",
          run_command     = "80",
          autorestart     = "OFF",
          autodestroy     = "ALWAYS",
          autoredeploy    = false,
          container_ports = {
            { protocol   = "tcp",
              inner_port = 80,
              -- outer_port = 80,
              published  = true,
            },
          },
        },
      }
      assert (service_status == 201)
      local _ = Token (Et.render ("/projects/<%- project %>", {
        project  = self.project.id,
      }), {
        timeout  = Config.editor.timeout,
        project  = self.project.id,
        resource = self.resource.id,
        api      = Et.render ("http://<%- host %>:<%- port %>/projects/<%- project %>/resources/<%- resource %>", {
          host     = Config.hostname,
          port     = Config.port,
          project  = self.project.id,
          resource = self.resource.id,
        }),
      })
      -- Start service:
      local resource = url .. service.resource_uri
      local _, started_status = Http.request {
        url        = resource .. "start/",
        method     = "POST",
        headers    = headers,
        timeout    = 5, -- seconds
      }
      assert (started_status == 202)
      local container
      repeat -- wait until it started
        if _G.ngx and _G.ngx.sleep then
          _G.ngx.sleep (1)
        else
          os.execute "sleep 1"
        end
        local result, status = Http.request {
          url     = resource,
          method  = "GET",
          headers = headers,
        }
        assert (status == 200)
        container = result.containers and url .. result.containers [1]
      until result.state:lower () == "running"
      local info, container_status = Http.request {
        url     = container,
        method  = "GET",
        headers = headers,
      }
      assert (container_status == 200)
      local endpoint = info.container_ports [1].endpoint_uri
      Database.query [[BEGIN]]
      self.resource:refresh ("editor_url", "docker_url")
      if self.resource.editor_url then
        Database.query [[ROLLBACK]]
        local _, deleted_status = Http.request {
          url     = resource,
          method  = "DELETE",
          headers = headers,
        }
        assert (deleted_status == 202)
      else
        self.resource:update {
          docker_url = resource,
          editor_url = endpoint,
        }
        assert (Database.query [[COMMIT]])
      end
      return {
        redirect_to = self.resource.editor_url:gsub ("^http", "ws"),
      }
    end,
    DELETE  = Decorators.exists {}
           .. Decorators.is_authentified
           .. function (self)
      if self.identity.type   ~= "project"
      or self.authentified.id ~= self.project.id then
        return { status = 403 }
      end
      if self.resource.editor_url then
        local headers = {
          ["Authorization"] = "Basic " .. Mime.b64 (Config.docker.username .. ":" .. Config.docker.api_key),
          ["Accept"       ] = "application/json",
          ["Content-type" ] = "application/json",
        }
        local _, deleted_status = Http.request {
          url     = self.resource.docker_url,
          method  = "DELETE",
          headers = headers,
        }
        assert (deleted_status == 202)
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
