local respond_to  = require "lapis.application".respond_to
local Decorators  = require "cosy.server.decorators"

return function (app)

  require "cosy.server.projects.permission" (app)

  app:match ("/projects/:project/permissions", respond_to {
    HEAD = Decorators.fetch_params ..
           Decorators.is_authentified ..
           Decorators.can_admin ..
           function ()
      return { status = 204 }
    end,
    OPTIONS = Decorators.fetch_params ..
              Decorators.is_authentified ..
              Decorators.can_admin ..
              function ()
      return { status = 204 }
    end,
    GET = Decorators.fetch_params ..
          Decorators.is_authentified ..
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
    DELETE = Decorators.fetch_params ..
             function ()
      return { status = 405 }
    end,
    PATCH = Decorators.fetch_params ..
            function ()
      return { status = 405 }
    end,
    POST = Decorators.fetch_params ..
           function ()
      return { status = 405 }
    end,
    PUT = Decorators.fetch_params ..
          function ()
      return { status = 405 }
    end,
  })

end
