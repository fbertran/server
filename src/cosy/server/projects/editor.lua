local Config      = require "lapis.config".get ()
local Database    = require "lapis.db"
local respond_to  = require "lapis.application".respond_to
local Decorators  = require "cosy.server.decorators"
local Token       = require "cosy.server.token"
local Http        = require "cosy.server.http"
local Ws          = require "cosy.server.ws"
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
          return {
            redirect_to = self.resource.editor_url,
          }
        end
      end
      local url     = "https://cloud.docker.com"
      local api     = url .. "/api/app/v1"
      local headers = {
        ["Authorization"] = "Basic " .. Mime.b64 (Config.docker.username .. ":" .. Config.docker.api_key),
      }
      if self.resource.docker_url then
        local _, status = Http.json {
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
      assert (service_status == 201)
      -- Start service:
      local resource = url .. service.resource_uri
      local _, started_status = Http.json {
        url        = resource .. "start/",
        method     = "POST",
        headers    = headers,
        timeout    = 5, -- seconds
      }
      assert (started_status == 202)
      local container
      for _ = 1, 10 do
        local result, status = Http.json {
          url     = resource,
          method  = "GET",
          headers = headers,
        }
        assert (status == 200)
        container = result.containers and url .. result.containers [1]
        if result.state:lower () == "running" then
          break
        elseif _G.ngx and _G.ngx.sleep then
          _G.ngx.sleep (1)
        else
          os.execute "sleep 1"
        end
      end
      assert (container)
      local info, container_status = Http.json {
        url     = container,
        method  = "GET",
        headers = headers,
      }
      assert (container_status == 200)
      local endpoint = info.container_ports [1].endpoint_uri:gsub ("^http", "ws")
      assert (Ws.test (endpoint, "cosy"))
      Database.query [[BEGIN]]
      self.resource:refresh ("editor_url", "docker_url")
      if self.resource.editor_url then
        Database.query [[ROLLBACK]]
        local _, deleted_status = Http.json {
          url     = resource,
          method  = "DELETE",
          headers = headers,
        }
        assert (deleted_status == 202)
        return { status = 409 }
      end
      self.resource:update {
        docker_url = resource,
        editor_url = endpoint,
      }
      assert (Database.query [[COMMIT]])
      return {
        redirect_to = self.resource.editor_url,
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
        }
        local _, deleted_status = Http.json {
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
