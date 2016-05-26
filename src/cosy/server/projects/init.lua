local respond_to  = require "lapis.application".respond_to
local Model       = require "cosy.server.model"
local Decorators  = require "cosy.server.decorators"

return function (app)

  require "cosy.server.projects.project"     (app)
  require "cosy.server.projects.permissions" (app)
  require "cosy.server.projects.resources"   (app)
  require "cosy.server.projects.stars"       (app)
  require "cosy.server.projects.tags"        (app)

  app:match ("/projects", respond_to {
    HEAD = function ()
      return {
        status = 204,
      }
    end,
    OPTIONS = function ()
      return { status = 204 }
    end,
    GET = function ()
      local projects = Model.projects:select () or {}
      for _, project in ipairs (projects) do
        project.stars = # project:get_stars ()
        project.tags  = project:get_tags  ()
      end
      return {
        status = 200,
        json   = projects,
      }
    end,
    POST = Decorators.is_authentified ..
           function (self)
      local project = Model.projects:create {
        name        = self.json.name,
        description = self.json.description,
        permission_anonymous = "read",
        permission_user      = "read",
      }
      Model.permissions:create {
        user_id    = self.authentified.id,
        project_id = project.id,
        permission = "admin",
      }
      return {
        status = 201,
        json   = project,
      }
    end,
    DELETE = function ()
      return { status = 405 }
    end,
    PATCH = function ()
      return { status = 405 }
    end,
    PUT = function ()
      return { status = 405 }
    end,
  })

end
