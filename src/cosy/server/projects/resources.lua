local respond_to  = require "lapis.application".respond_to
local Model       = require "cosy.server.model"
local Decorators  = require "cosy.server.decorators"

return function (app)

  require "cosy.server.projects.resource" (app)

  app:match ("/projects/:project/resources", respond_to {
    HEAD = Decorators.exists {} ..
           Decorators.can_read ..
           function ()
      return { status = 204 }
    end,
    OPTIONS = Decorators.exists {} ..
              Decorators.can_read ..
              function ()
      return { status = 204 }
    end,
    GET = Decorators.exists {} ..
          Decorators.can_read ..
          function (self)
      return {
        status = 200,
        json   = self.project:get_resources () or {},
      }
    end,
    POST = Decorators.exists {} ..
           Decorators.can_write ..
           function (self)
      local resource = Model.resources:create {
        project_id  = self.project.id,
        name        = self.json.name,
        description = self.json.description,
        data        = self.json.data or [[ return function () end ]],
      }
      return {
        status = 201,
        json   = resource,
      }
    end,
    DELETE = Decorators.exists {} ..
             function ()
      return { status = 405 }
    end,
    PATCH = Decorators.exists {} ..
            function ()
      return { status = 405 }
    end,
    PUT = Decorators.exists {} ..
          function ()
      return { status = 405 }
    end,
  })

end
