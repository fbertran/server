local respond_to  = require "lapis.application".respond_to
local Model       = require "cosy.server.model"
local Decorators  = require "cosy.server.decorators"

local function is_permission (permission)
  return  permission ~= nil
     and (permission == "none"
      or  permission == "read"
      or  permission == "write"
      or  permission == "admin")
end

return function (app)

  for _, special in ipairs { "anonymous", "user" } do
    app:match ("/projects/:project/permissions/" .. special, respond_to {
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
        return {
          status = 200,
          json   = {
            project_id = self.project.id,
            permission = self.project.permission,
          },
        }
      end,
      PUT     = Decorators.exists {}
             .. Decorators.can_admin
             .. function (self)
        if not is_permission (self.json.permission) then
          return { status = 400 }
        end
        self.project:update {
          ["permission_" .. special] = self.json.permission,
        }
        return { status = 202 }
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
    })
  end

  app:match ("/projects/:project/permissions/:user", respond_to {
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
      return {
        status = 200,
        json   = Model.permissions:find {
          identity_id = self.user.id,
          project_id  = self.project.id,
        },
      }
    end,
    PUT     = Decorators.exists { "user" }
           .. Decorators.can_admin
           .. function (self)
      if not is_permission (self.json.permission) then
        return { status = 400 }
      end
      local permission = Model.permissions:find {
        identity_id = self.user.id,
        project_id  = self.project.id,
      }
      if permission then
        permission:update {
          permission = self.json.permission,
        }
        return { status = 202 }
      else
        Model.permissions:create {
          identity_id = self.user.id,
          project_id  = self.project.id,
          permission  = self.json.permission,
        }
        return { status = 201 }
      end
    end,
    DELETE  = Decorators.exists {}
           .. Decorators.can_admin
           .. function (self)
      local permission = Model.permissions:find {
        identity_id = self.user.id,
        project_id  = self.project.id,
      }
      if not permission then
       return { status = 404 }
      end
      local count = Model.permissions:count ([[ project_id = ? and permission = 'admin' and identity_id != ? ]], self.project.id, self.project.id)
      if count < 2 then
        return { status = 409 }
      end
      permission:delete ()
      return { status = 204 }
    end,
    PATCH   = Decorators.exists {}
           .. function ()
      return { status = 405 }
    end,
    POST    = Decorators.exists {}
           .. function ()
      return { status = 405 }
    end,
  })

end
