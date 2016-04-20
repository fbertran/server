local respond_to  = require "lapis.application".respond_to
local json_params = require "lapis.application".json_params
local Util        = require "lapis.util"
local Model       = require "cosy.server.model"
local Decorators  = require "cosy.server.decorators"

return function (app)

  app:match ("/projects/:project/resources", respond_to {
    HEAD = Decorators.param_is_project "project" ..
           function ()
      return { status = 204 }
    end,
    GET = Decorators.param_is_project "project" ..
          function (self)
      local tags = self.project:get_resources () or {}
      return {
        status = 200,
        json   = tags,
      }
    end,
    OPTIONS = Decorators.param_is_project "project" ..
              function ()
      return { status = 204 }
    end,
    DELETE = Decorators.param_is_project "project" ..
             function ()
      return { status = 405 }
    end,
    PATCH = Decorators.param_is_project "project" ..
            function ()
      return { status = 405 }
    end,
    POST = Decorators.param_is_project "project" ..
            function ()
      return { status = 405 }
    end,
    PUT = Decorators.param_is_project "project" ..
          function ()
      return { status = 405 }
    end,
  })

  app:match ("/projects/:project/resources/(:resource)", respond_to {
    HEAD = Decorators.param_is_project "project" ..
           function ()
      return { status = 204 }
    end,
    GET = Decorators.param_is_project "project" ..
          Decorators.param_is_resource "resource" ..
          function (self)
      return {
        status = 200,
        json   = self.resource,
      }
    end,
    PUT = json_params ..
          Decorators.is_authentified ..
          Decorators.param_is_project "project" ..
          Decorators.optional (Decorators.param_is_resource "resource") ..
          function (self)
      if self.authentified.id ~= self.project.user_id then
        return { status = 403 }
      end
      if self.resource then
        self.resource:update {
          name        = self.params.name,
          description = self.params.description,
          history     = self.params.history,
          data        = self.params.data,
        }
        return { status = 204 }
      else
        Model.resources:create {
          id          = Util.unescape (self.params.resource),
          project_id  = self.project.id,
          name        = self.params.name,
          description = self.params.description,
          history     = self.params.history,
          data        = self.params.data,
        }
        return { status = 201 }
      end
    end,
    PATCH = json_params ..
            Decorators.is_authentified ..
            Decorators.param_is_serial "project" ..
            Decorators.param_is_resource "resource" ..
            function (self)
      if self.authentified.id ~= self.project.user_id then
        return { status = 403 }
      end
      self.resource:update {
        name        = self.params.name,
        description = self.params.description,
        history     = self.params.history,
        data        = self.params.data,
      }
      return { status = 204 }
    end,
    DELETE = Decorators.is_authentified ..
             Decorators.param_is_project "project" ..
             Decorators.param_is_resource "resource" ..
             function (self)
      if self.authentified.id ~= self.project.user_id then
        return { status = 403 }
      end
      self.resource:delete ()
      return { status = 204 }
    end,
    OPTIONS = Decorators.param_is_serial "project" ..
              function ()
      return { status = 204 }
    end,
    POST = Decorators.param_is_serial "project" ..
           function ()
      return { status = 405 }
    end,
  })

end
