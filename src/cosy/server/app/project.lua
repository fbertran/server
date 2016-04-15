local respond_to  = require "lapis.application".respond_to
local json_params = require "lapis.application".json_params
local Model       = require "cosy.server.model"
local Decorators  = require "cosy.server.decorators"

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
    POST = json_params
        .. Decorators.is_authentified
        .. function (self)
      local project = Model.projects:create {
        user_id     = self.authentified.id,
        name        = self.params.name,
        description = self.params.description,
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
    HEAD = Decorators.param_is_project "project"
        .. function ()
      return {
        status = 200,
      }
    end,
    GET = Decorators.param_is_project "project"
       .. function (self)
      local resources = {}
      for i, resource in ipairs (self.project:get_resources () or {}) do
        resources [i] = {
          id          = resource.id,
          name        = resource.name,
          description = resource.description,
        }
      end
      return {
        status = 200,
        json   = {
          id          = self.project.id,
          owner       = self.project.user_id,
          name        = self.project.name,
          description = self.project.description,
          resources   = resources,
        },
      }
    end,
    PATCH = json_params
         .. Decorators.param_is_project "project"
         .. Decorators.is_authentified
         .. function (self)
      if self.authentified.id ~= self.project.user_id then
        return {
          status = 403,
        }
      end
      self.project:update {
        name        = self.params.name,
        description = self.params.description,
      }
      return {
        status = 204,
      }
    end,
    DELETE = Decorators.param_is_project "project"
          .. Decorators.is_authentified
          .. function (self)
      if self.authentified.id ~= self.project.user_id then
        return {
          status = 403,
        }
      end
      self.project:delete ()
      return {
        status = 204,
      }
    end,
    OPTIONS = Decorators.param_is_serial "project"
           .. function ()
      return { status = 200 }
    end,
    PUT = Decorators.param_is_serial "project"
       .. function ()
      return { status = 405 }
    end,
    POST = Decorators.param_is_serial "project"
        .. function ()
      return { status = 405 }
    end,
  })

end
