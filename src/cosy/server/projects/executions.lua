local Config     = require "lapis.config".get ()
local respond_to = require "lapis.application".respond_to
local Model      = require "cosy.server.model"
local Decorators = require "cosy.server.decorators"
local Http       = require "cosy.server.http"
local Hashid     = require "cosy.server.hashid"
local Et         = require "etlua"
local Qless      = require "resty.qless"

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
           .. Decorators.is_user
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
      local qless = Qless.new {
        host = Config.redis.host,
        port = Config.redis.port,
        db   = Config.redis.database,
      }
      local queue     = qless.queues ["executions"]
      local execution = Model.executions:create {
        project_id  = self.project.id,
        resource    = self.json.resource,
        image       = self.json.image,
        name        = self.json.name,
        description = self.json.description,
      }
      execution:update {
        url = Et.render ("/projects/<%- project %>/executions/<%- execution %>", {
          project   = Hashid.encode (self.project.id),
          execution = Hashid.encode (execution.id),
        }),
      }
      queue:put ("cosy.server.jobs.execution", {
        execution = execution.id,
      }, {
        jid = execution.url,
      })
      for _ = 1, 30 do
        execution:refresh ()
        if execution.docker_url then
          return {
            status = 201,
            json   = execution,
          }
        end
        _G.ngx.sleep (1)
      end
      return { status = 503 }
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
