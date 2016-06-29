local respond_to = require "lapis.application".respond_to
local Decorators = require "cosy.server.decorators"
local Model      = require "cosy.server.model"

return function (app)

  app:match ("/projects/:project/resources/:resource/aliases/:alias", respond_to {
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
        json = self.alias,
      }
    end,
    DELETE = Decorators.exists {} ..
             Decorators.can_write ..
             function (self)
      self.alias:delete ()
      return { status = 204 }
    end,
    PUT = Decorators.exists { alias = true } ..
          Decorators.can_write ..
          function (self)
      if self.alias then
        return { status = 202 }
      end
      local alias = Model.aliases:create {
        id          = self.params.alias,
        resource_id = self.resource.id,
      }
      return {
        status = 201,
        json = alias,
      }
    end,
    PATCH = Decorators.exists {} ..
            function ()
      return { status = 405 }
    end,
    POST = Decorators.exists {} ..
           function ()
      return { status = 405 }
    end,
  })

end
