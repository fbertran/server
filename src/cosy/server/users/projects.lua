local respond_to  = require "lapis.application".respond_to
local json_params = require "lapis.application".json_params
local Model       = require "cosy.server.model"
local Decorators  = require "cosy.server.decorators"

return function (app)

  app:match ("/users/:user/projects", respond_to {
    HEAD = Decorators.param_is_user "user" ..
           function ()
      return { status = 204 }
    end,
    OPTIONS = Decorators.param_is_user "user" ..
              function ()
      return { status = 204 }
    end,
    GET = Decorators.param_is_user "user" ..
          function (self)
      return {
        status = 200,
        json   = self.user:get_projects () or {},
      }
    end,
    POST = json_params ..
           Decorators.param_is_user "user" ..
           Decorators.is_authentified ..
           function (self)
      local resource = Model.projects:create {
        user_id     = self.user.id,
        name        = self.params.name,
        description = self.params.description,
      }
      return {
        status = 201,
        json   = resource,
      }
    end,
    DELETE = Decorators.param_is_user "user" ..
             function ()
      return { status = 405 }
    end,
    PATCH = Decorators.param_is_user "user" ..
            function ()
      return { status = 405 }
    end,
    PUT = Decorators.param_is_user "user" ..
          function ()
      return { status = 405 }
    end,
  })

end
