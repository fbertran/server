local respond_to  = require "lapis.application".respond_to
local json_params = require "lapis.application".json_params
local Model       = require "cosy.server.model"
local Decorators  = require "cosy.server.decorators"

local function is_permission (permission)
  return permission ~= nil
     and (permission == "none"
      or  permission == "read"
      or  permission == "write"
      or  permission == "admin")
end

return function (app)

  for _, special in ipairs { "anonymous", "user" } do
    app:match ("/projects/:project/permissions/" .. special, respond_to {
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
            project_id = self.project.id,
            permission = self.project.permission,
          },
        }
      end,
      PUT = json_params ..
            Decorators.fetch_params ..
            Decorators.is_authentified ..
            Decorators.can_admin ..
            function (self)
        if not is_permission (self.params.permission) then
          return { status = 400 }
        end
        self.project:update {
          ["permission_" .. special] = self.params.permission,
        }
        return { status = 202 }
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
    })
  end

  app:match ("/projects/:project/permissions/:user", respond_to {
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
        json   = Model.permissions:get {
          user_id    = self.params.user,
          project_id = self.params.project,
        },
      }
    end,
    PUT = json_params ..
          Decorators.fetch_params ..
          Decorators.is_authentified ..
          Decorators.can_admin ..
          function (self)
      if not is_permission (self.params.permission) then
        return { status = 400 }
      end
      local permission = Model.permissions:find {
        user_id    = self.params.user,
        project_id = self.project.id,
      }
      if permission then
        permission:update {
          permission = self.params.permission,
        }
        return { status = 202 }
      else
        Model.permissions:create {
          user_id    = self.params.user,
          project_id = self.project.id,
          permission = self.params.permission,
        }
        return { status = 201 }
      end
    end,
    DELETE = Decorators.fetch_params ..
             Decorators.is_authentified ..
             Decorators.can_admin ..
             function (self)
      local permission = Model.permissions:find {
        user_id    = self.params.user,
        project_id = self.project.id,
      }
      if not permission then
       return { status = 404 }
      end
      local count = Model.permissions:count ([[ project_id = ? and permission = 'admin' ]], self.params.project.id)
      if count < 2 then
        return { status = 409 }
      end
      permission:delete ()
      return { status = 204 }
    end,
    PATCH = Decorators.fetch_params ..
            Decorators.is_authentified ..
            Decorators.can_admin ..
            function ()
      return { status = 405 }
    end,
    POST = Decorators.fetch_params ..
           Decorators.is_authentified ..
           Decorators.can_admin ..
           function ()
      return { status = 405 }
    end,
  })

end
