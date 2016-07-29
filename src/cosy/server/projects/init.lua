local Et         = require "etlua"
local respond_to = require "lapis.application".respond_to
local Model      = require "cosy.server.model"
local Decorators = require "cosy.server.decorators"

return function (app)

  require "cosy.server.projects.executions"  (app)
  require "cosy.server.projects.project"     (app)
  require "cosy.server.projects.permissions" (app)
  require "cosy.server.projects.resources"   (app)
  require "cosy.server.projects.stars"       (app)
  require "cosy.server.projects.tags"        (app)

  app:match ("/projects(/)", respond_to {
    HEAD    = function ()
      return { status = 204 }
    end,
    OPTIONS = function ()
      return { status = 204 }
    end,
    GET     = function ()
      local projects = Model.projects:select {
        fields = "id",
      } or {}
      return {
        status = 200,
        json   = projects,
      }
    end,
    POST    = Decorators.is_authentified
           .. function (self)
      if self.identity.type ~= "user" then
        return { status = 403 }
      end
      local identity = Model.identities:create {
        identifier = nil,
        type       = "project",
      }
      identity:update {
        identifier = Et.render ("/projects/<%- id %>", {
          id = identity.id,
        }),
      }
      local project = Model.projects:create {
        id          = identity.id,
        name        = self.json.name,
        description = self.json.description,
        permission_anonymous = "read",
        permission_user      = "read",
      }
      Model.permissions:create {
        identity_id = identity.id,
        project_id  = project.id,
        permission  = "admin",
      }
      Model.permissions:create {
        identity_id = self.identity.id,
        project_id  = project.id,
        permission  = "admin",
      }
      return {
        status = 201,
        json   = project,
      }
    end,
    DELETE  = function ()
      return { status = 405 }
    end,
    PATCH   = function ()
      return { status = 405 }
    end,
    PUT     = function ()
      return { status = 405 }
    end,
  })

end
