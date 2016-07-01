local Config      = require "lapis.config".get ()
local Database    = require "lapis.db"
local Util        = require "lapis.util"
local respond_to  = require "lapis.application".respond_to
local Decorators  = require "cosy.server.decorators"
local Token       = require "cosy.server.token"
local Et          = require "etlua"
local Http        = require "resty.http"
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
        ["Authorization"] = "Basic " .. _G.ngx.encode_base64 (Config.docker.username .. ":" .. Config.docker.api_key),
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
        local client = Http.new ()
        local result = client:request_uri (self.resource.docker_url, {
          method     = "DELETE",
          headers    = headers,
          ssl_verify = Config._name ~= "test",
        })
        assert (result.status == 202)
        self.resource:update ({
          editor_url = Database.NULL,
          docker_url = Database.NULL,
        }, { timestamp = false })
      end
      local client = Http.new ()
      -- Create service:
      local result = client:request_uri (api .. "/service/", {
        method  = "POST",
        headers = headers,
        body    = Util.to_json {
          image           = "dataferret/websocket-echo",
          run_command     = "80",
          autodestroy     = "ALWAYS",
          autoredeploy    = false,
          container_ports = {
            { protocol   = "tcp",
              inner_port = 80,
              outer_port = 80,
              published  = true,
            },
          },
        },
        ssl_verify = Config._name ~= "test",
      })
      local _ = Token (Et.render ("/projects/<%- project %>", {
        project  = self.project.id,
      }), {
        timeout  = Config.editor.timeout,
        project  = self.project.id,
        resource = self.resource.id,
        api      = Et.render ("http://<%- host %>:<%- port %>/projects/<%- project %>/resources/<%- resource %>", {
          host     = os.getenv "NGINX_HOST",
          port     = os.getenv "NGINX_PORT",
          project  = self.project.id,
          resource = self.resource.id,
        }),
      })
      assert (result.status == 201)
      -- Start service:
      local resource = url .. Util.from_json (result.body).resource_uri
      result   = client:request_uri (resource .. "start/", {
        method     = "POST",
        headers    = headers,
        ssl_verify = Config._name ~= "test",
      })
      assert (result.status == 202)
      local container = url .. Util.from_json (result.body).containers [1]
      repeat -- wait until it started
        _G.ngx.sleep (1)
        result = client:request_uri (resource, {
          method     = "GET",
          headers    = headers,
          ssl_verify = Config._name ~= "test",
        })
        assert (result.status == 200)
        local body = Util.from_json (result.body)
      until body.state:lower () == "running"
      result = client:request_uri (container, {
        method     = "GET",
        headers    = headers,
        ssl_verify = Config._name ~= "test",
      })
      assert (result.status == 200)
      local endpoint = Util.from_json (result.body).container_ports [1].endpoint_uri
      Database.query [[BEGIN]]
      self.resource:refresh ("editor_url", "docker_url")
      if self.resource.editor_url then
        Database.query [[ROLLBACK]]
        result = client:request_uri (resource, {
          method     = "DELETE",
          headers    = headers,
          ssl_verify = Config._name ~= "test",
        })
        assert (result.status == 202)
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
        local client = Http.new ()
        local headers = {
          ["Authorization"] = "Basic " .. _G.ngx.encode_base64 (Config.docker.username .. ":" .. Config.docker.api_key),
          ["Accept"       ] = "application/json",
          ["Content-type" ] = "application/json",
        }
        local result = client:request_uri (self.resource.docker_url, {
          method     = "DELETE",
          headers    = headers,
          ssl_verify = Config._name ~= "test",
        })
        assert (result.status == 202)
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
