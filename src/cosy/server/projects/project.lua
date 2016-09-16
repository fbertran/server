local Config     = require "lapis.config".get ()
local respond_to = require "lapis.application".respond_to
local Decorators = require "cosy.server.decorators"
local Http       = require "cosy.server.http"
local Token      = require "cosy.server.token"
local Url        = require "socket.url"

return function (app)

  app:match ("/projects/:project", respond_to {
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
      self.project.tags      = self.project:get_tags      () or {}
      self.project.resources = self.project:get_resources () or {}
      return {
        status = 200,
        json   = self.project,
      }
    end,
    PATCH   = Decorators.exists {}
           .. Decorators.can_write
           .. function (self)
      self.project:update {
        name        = self.params.name,
        description = self.params.description,
      }
      return {
        status = 204,
      }
    end,
    DELETE  = Decorators.exists {}
           .. Decorators.can_admin
           .. function (self)
      local token = Token (self.project.url, {}, math.huge)
      if Config._name ~= "test" then
        for _, resource in ipairs (self.project:get_resources ()) do
          local _, status = Http.json {
            url     = Url.build {
              scheme = "http",
              host   = Config.host,
              port   = Config.port,
              path   = resource.url,
            },
            method  = "DELETE",
            headers = {
              Authorization = "Bearer " .. token,
            },
          }
          assert (status == 204)
        end
        for _, execution in ipairs (self.project:get_executions ()) do
          local _, status = Http.json {
            url     = Url.build {
              scheme = "http",
              host   = Config.host,
              port   = Config.port,
              path   = execution.url,
            },
            method  = "DELETE",
            headers = {
              Authorization = "Bearer " .. token,
            },
          }
          assert (status == 204)
        end
      end
      self.project:get_identity ():delete ()
      return {
        status = 204,
      }
    end,
    PUT     = Decorators.exists {}
           .. function ()
      return { status = 405 }
    end,
    POST    = Decorators.exists {}
           .. function ()
      return { status = 405 }
    end,
  })

end
