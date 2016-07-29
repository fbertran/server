local Config      = require "lapis.config".get ()
local Database    = require "lapis.db"
local respond_to  = require "lapis.application".respond_to
local Decorators  = require "cosy.server.decorators"
local Http        = require "cosy.server.http"
local Mime        = require "mime"

return function (app)

  app:match ("/projects/:project/executions/:execution", respond_to {
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
      if self.execution.docker_url then
        local headers = {
          ["Authorization"] = "Basic " .. Mime.b64 (Config.docker.username .. ":" .. Config.docker.api_key),
          ["Accept"       ] = "application/json",
          ["Content-type" ] = "application/json",
        }
        local result, status = Http.json {
          url     = self.execution.docker_url,
          method  = "GET",
          headers = headers,
        }
        if status == 404 then
          self.execution:update ({
            docker_url = Database.NULL,
          }, { timestamp = false })
        else
          assert (status == 200)
          if  result.state:lower () == "exited" then
            self.execution:update ({
              docker_url = Database.NULL,
            }, { timestamp = false })
          end
        end
      end
      return {
        status = 200,
        json   = self.execution,
      }
    end,
    DELETE  = Decorators.exists {}
           .. Decorators.can_write
           .. function (self)
      if self.execution.docker_url then
        local headers = {
          ["Authorization"] = "Basic " .. Mime.b64 (Config.docker.username .. ":" .. Config.docker.api_key),
          ["Accept"       ] = "application/json",
          ["Content-type" ] = "application/json",
        }
        local result, deleted_status = Http.json {
          url     = self.execution.docker_url,
          method  = "DELETE",
          headers = headers,
        }
        local Json = require "cjson"
        assert (deleted_status == 202, Json.encode (result))
      end
      self.execution:delete ()
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
