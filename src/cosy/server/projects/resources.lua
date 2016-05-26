local respond_to  = require "lapis.application".respond_to
local Model       = require "cosy.server.model"
local Decorators  = require "cosy.server.decorators"

return function (app)

  app:match ("/projects/:project/resources", respond_to {
    HEAD = function ()
      return { status = 204 }
    end,
    GET = function (self)
      return {
        status = 200,
        json   = self.project:get_resources () or {},
      }
    end,
    POST = Decorators.can_write ..
           function (self)
      local resource = Model.resources:create {
        project_id  = self.project.id,
        name        = self.params.name,
        description = self.params.description,
      }
      return {
        status = 201,
        json   = resource,
      }
    end,
    OPTIONS = function ()
      return { status = 204 }
    end,
    DELETE = function ()
      return { status = 405 }
    end,
    PATCH = function ()
      return { status = 405 }
    end,
    PUT = function ()
      return { status = 405 }
    end,
  })

end
