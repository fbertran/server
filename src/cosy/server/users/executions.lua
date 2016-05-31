local respond_to  = require "lapis.application".respond_to
local Model       = require "cosy.server.model"
local Decorators  = require "cosy.server.decorators"

return function (app)

  require "cosy.server.users.execution" (app)

  app:match ("/users/:user/executions", respond_to {
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
        json   = self.user:get_executions () or {},
      }
    end,
    POST = Decorators.exists {} ..
           Decorators.can_write ..
           function (self)
      if not self.json.resource or not tonumber (self.json.resource) then
        return { status = 400 }
      end
      if not self.json.resource or not tonumber (self.json.resource) then
        return { status = 400 }
      end
      local resource = Model.executions:create {
        user_id     = self.user.id,
        resource_id = self.json.resource,
        name        = self.json.name,
        description = self.json.description,
      }
      -- TODO: run execution
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
