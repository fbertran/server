local respond_to = require "lapis.application".respond_to
local Decorators = require "cosy.server.decorators"
local Model      = require "cosy.server.model"

return function (app)

  require "cosy.server.projects.permission" (app)

  app:match ("/projects/:project/permissions(/)", respond_to {
    HEAD    = Decorators.exists {}
           .. Decorators.can_admin
           .. function ()
      return { status = 204 }
    end,
    OPTIONS = Decorators.exists {}
           .. Decorators.can_admin
           .. function ()
      return { status = 204 }
    end,
    GET     = Decorators.exists {}
           .. Decorators.can_admin
           .. function (self)
      local permissions = self.project:get_permissions () or {}
      local granted      = {}
      for i, permission in ipairs (permissions) do
        local user = Model.users:find {
          id = permission.identity_id,
        }
        local project = Model.projects:find {
          id = permission.identity_id,
        }
        if user then
          granted [i] = {
            project = self.project.path,
            who     = user.path,
            type    = "user",
          }
        else
          granted [i] = {
            project = self.project.path,
            who     = project.path,
            type    = "project",
          }
        end
      end
      return {
        status = 200,
        json   = {
          path      = self.project.path .. "/permissions/",
          anonymous = self.project.permission_anonymous,
          user      = self.project.permission_user,
          granted   = granted,
        },
      }
    end,
    DELETE  = Decorators.exists {}
           .. function ()
      return { status = 405 }
    end,
    PATCH   = Decorators.exists {}
           .. function ()
      return { status = 405 }
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
