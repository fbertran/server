local respond_to = require "lapis.application".respond_to
local Model      = require "cosy.server.model"
local Util       = require "lapis.util"

return function (app)

  app:match ("/projects(/)", respond_to {
    HEAD = function ()
      return {
        status = 200,
      }
    end,
    GET = function ()
      local projects = {}
      for i, project in ipairs (Model.projects:select () or {}) do
        projects [i] = {
          id          = project.id,
          user        = project.user_id,
          name        = project.name,
          description = project.description,
          stars       = # (project:get_stars () or {}),
          tags        = project:get_tags () or {},
        }
      end
      return {
        status = 200,
        json   = projects,
      }
    end,
    POST = function (self)
      if not self.token then
        return {
          status = 401,
        }
      end
      local user = Model.identities:find (self.token.sub)
      if not user then
        return {
          status = 401,
        }
      end
      local project = Model.projects:create {
        user_id = user.user_id,
      }
      return {
        status = 200,
        json   = {
          id = project.id,
        },
      }
    end,
    OPTIONS = function ()
      return { status = 200 }
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

  app:match ("/projects/:project(/)", respond_to {
    HEAD = function (self)
      local id = Util.unescape (self.params.project)
      if not tonumber (id) then
        return {
          status = 400,
        }
      end
      local project = Model.projects:find (id)
      if not project then
        return {
          status = 404,
        }
      end
      return {
        status = 200,
      }
    end,
    GET = function (self)
      local id = Util.unescape (self.params.project)
      if not tonumber (id) then
        return {
          status = 400,
        }
      end
      local project = Model.projects:find (id)
      if not project then
        return {
          status = 404,
        }
      end
      local resources = {}
      for i, resource in ipairs (project:get_resources () or {}) do
        resources [i] = {
          id          = resource.id,
          name        = resource.name,
          description = resource.description,
        }
      end
      return {
        status = 200,
        json   = {
          id          = project.id,
          owner       = project.user_id,
          name        = project.name,
          description = project.description,
          resources   = resources,
        },
      }
    end,
    PATCH = function (self)
      local id = Util.unescape (self.params.project)
      if not tonumber (id) then
        return {
          status = 400,
        }
      end
      if not self.token then
        return {
          status = 401,
        }
      end
      local project = Model.projects:find (id)
      if not project then
        return {
          status = 404,
        }
      end
      local user = Model.identities:find (self.token.sub)
      if not user or user.user_id ~= project.user_id then
        return {
          status = 403,
        }
      end
      -- TODO
      return {
        status = 204,
      }
    end,
    DELETE = function (self)
      local id = Util.unescape (self.params.project)
      if not tonumber (id) then
        return {
          status = 400,
        }
      end
      if not self.token then
        return {
          status = 401,
        }
      end
      local project = Model.projects:find (id)
      if not project then
        return {
          status = 404,
        }
      end
      local user = Model.identities:find (self.token.sub)
      if not user or user.user_id ~= project.user_id then
        return {
          status = 403,
        }
      end
      project:delete ()
      return {
        status = 204,
      }
    end,
    OPTIONS = function (self)
      local id = Util.unescape (self.params.project)
      if not tonumber (id) then
        return {
          status = 400,
        }
      end
      return { status = 200 }
    end,
    PUT = function (self)
      local id = Util.unescape (self.params.project)
      if not tonumber (id) then
        return {
          status = 400,
        }
      end
      return { status = 405 }
    end,
    POST = function (self)
      local id = Util.unescape (self.params.project)
      if not tonumber (id) then
        return {
          status = 400,
        }
      end
      return { status = 405 }
    end,
  })

end
