local respond_to = require "lapis.application".respond_to
local Decorators = require "cosy.server.decorators"
local Hashid     = require "cosy.server.hashid"
local Job        = require "cosy.server.jobs.execution"

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
      return {
        status = 200,
        json   = {
          id          = Hashid.encode (self.execution.id),
          path        = self.execution.path,
          project     = self.execution:get_project ().path,
          name        = self.execution.name,
          description = self.execution.description,
          docker      = self.execution.docker_url,
        },
      }
    end,
    PATCH   = Decorators.exists {}
           .. Decorators.can_write
           .. function (self)
      self.execution:update {
        name        = self.json.name,
        description = self.json.description,
      }
      return { status = 204 }
    end,
    DELETE  = Decorators.exists {}
           .. Decorators.can_write
           .. function (self)
      Job.stop (self.execution)
      return { status = 202 }
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
