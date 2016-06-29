local Et         = require "etlua"
local respond_to = require "lapis.application".respond_to
local Model      = require "cosy.server.model"
local Decorators = require "cosy.server.decorators"

return function (app)

  local function redirect (self)
    local resource = Model.resources:find {
      id = self.alias.resource_id,
    }
    return {
      redirect_to = Et.render ("/projects/<%- project %>/resources/<%- resource %>", {
        project  = resource.project_id,
        resource = resource.id,
      }),
    }
  end

  app:match ("/aliases/:alias", respond_to {
    HEAD = Decorators.exists {} ..
           function (self)
      return redirect (self)
    end,
    OPTIONS = Decorators.exists {} ..
              function (self)
      return redirect (self)
    end,
    GET = Decorators.exists {} ..
          function (self)
      return redirect (self)
    end,
    POST = Decorators.exists {} ..
           function ()
      return { status = 405 }
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
