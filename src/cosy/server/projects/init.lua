local respond_to = require "lapis.application".respond_to
local Util       = require "lapis.util"
local Model      = require "cosy.server.model"
local Decorators = require "cosy.server.decorators"
local Hashid     = require "cosy.server.hashid"
local Et         = require "etlua"

return function (app)

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
      local projects = Model.projects:select () or {}
      local result   = {
        path     = "/projects/",
        projects = {},
      }
      for i, project in ipairs (projects) do
        local all_stars = project:get_stars () or {}
        local stars     = {
          count = #all_stars,
          path  = project.path .. "/stars",
        }
        local all_tags  = project:get_tags  () or {}
        local tags      = {
          path = project.path .. "/tags",
          tags = {},
        }
        for j, tag in ipairs (all_tags) do
          tags.tags [j] = {
            id   = tag.id,
            path = project.path .. "/tag/" .. Util.escape (tag.id),
          }
        end
        result.projects [i] = {
          path        = project.path,
          name        = project.name,
          description = project.description,
          stars       = stars,
          tags        = tags,
        }
      end
      return {
        status = 200,
        json   = result,
      }
    end,
    POST    = Decorators.is_authentified
           .. function (self)
      local project = Model.projects:create {
        path                 = "FIXME",
        name                 = self.json.name,
        description          = self.json.description,
        permission_anonymous = "read",
        permission_user      = "read",
      }
      project:update {
        path = Et.render ("/projects/<%- project %>", {
          project = Hashid.encode (project.id),
        }),
      }
      local identity = Model.identities:create {
        id         = project.id,
        identifier = project.path,
        type       = "project",
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
        json   = {
          id   = Hashid.encode (project.id),
          path = project.path,
        },
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
