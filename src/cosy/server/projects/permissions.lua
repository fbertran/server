local respond_to  = require "lapis.application".respond_to
local Decorators  = require "cosy.server.decorators"

return function (app)

  require "cosy.server.projects.permission" (app)

  app:match ("/projects/:project/permissions(/)", respond_to {
    HEAD = Decorators.exists {} ..
           Decorators.can_admin ..
           function ()
      return { status = 204 }
    end,
    OPTIONS = Decorators.exists {} ..
              Decorators.can_admin ..
              function ()
      return { status = 204 }
    end,
    GET = Decorators.exists {} ..
          Decorators.can_admin ..
          function (self)
      return {
        status = 200,
        json   = {
          anonymous = self.project.permission_anonymous,
          user      = self.project.permission_user,
          granted   = self.project:get_permissions () or {},
        },
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
    POST = Decorators.exists {} ..
           function ()
      return { status = 405 }
    end,
    PUT = Decorators.exists {} ..
          function ()
      return { status = 405 }
    end,
  })

end
