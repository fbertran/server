local respond_to  = require "lapis.application".respond_to
local json_params = require "lapis.application".json_params
local Util        = require "lapis.util"
local Model       = require "cosy.server.model"
local Decorators  = require "cosy.server.decorators"

return function (app)

  app:match ("/projects(/)", respond_to {
    HEAD = function ()
      return {
        status = 204,
      }
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
    POST = json_params
        .. Decorators.is_authentified
        .. function (self)
      local project = Model.projects:create {
        user_id     = self.authentified.id,
        name        = self.params.name,
        description = self.params.description,
      }
      return {
        status = 201,
        json   = project,
      }
    end,
    OPTIONS = function ()
      return { status = 204 }
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
        status = 204,
      }
    end,
    GET = Decorators.param_is_project "project"
       .. function (self)
      self.project.resources = self.project:get_resources () or {}
      return {
        status = 200,
        json   = self.project,
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
      return { status = 204 }
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

  app:match ("/projects/:project/tags(/)", respond_to {
    HEAD = Decorators.param_is_project "project"
        .. function ()
      return {
        status = 204,
      }
    end,
    GET = Decorators.param_is_project "project"
       .. function (self)
      local tags = self.project:get_tags () or {}
      return {
        status = 200,
        json   = tags,
      }
    end,
    OPTIONS = Decorators.param_is_project "project"
           .. function ()
      return { status = 204 }
    end,
    DELETE = Decorators.param_is_project "project"
          .. function ()
      return { status = 405 }
    end,
    PATCH = Decorators.param_is_project "project"
         .. function ()
      return { status = 405 }
    end,
    POST = Decorators.param_is_project "project"
         .. function ()
      return { status = 405 }
    end,
    PUT = Decorators.param_is_project "project"
       .. function ()
      return { status = 405 }
    end,
  })

  app:match ("/projects/:project/tags/(:tag)(/)", respond_to {
    HEAD = Decorators.param_is_project "project"
        .. function ()
      return {
        status = 204,
      }
    end,
    GET = Decorators.param_is_project "project"
       .. function (self)
      local id  = Util.unescape (self.params.tag)
      local tag = Model.tags:find {
        id         = id,
        project_id = self.project.id,
      }
      if not tag then
        return {
          status = 404,
        }
      end
      return {
        status = 200,
        json   = tag,
      }
    end,
    PUT = json_params
         .. Decorators.param_is_project "project"
         .. Decorators.is_authentified
         .. function (self)
      if self.authentified.id ~= self.project.user_id then
        return {
          status = 403,
        }
      end
      local id  = Util.unescape (self.params.tag)
      local tag = Model.tags:find {
        id         = id,
        project_id = self.project.id,
      }
      if tag then
        return {
          status = 202,
        }
      end
      Model.tags:create {
        id         = id,
        project_id = self.project.id,
      }
      return {
        status = 201,
        json   = tag,
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
      local id  = Util.unescape (self.params.tag)
      local tag = Model.tags:find {
        id         = id,
        project_id = self.project.id,
      }
      if not tag then
        return {
          status = 202,
        }
      end
      tag:delete ()
      return {
        status = 204,
      }
    end,
    OPTIONS = Decorators.param_is_serial "project"
           .. function ()
      return { status = 204 }
    end,
    PATCH = Decorators.param_is_serial "project"
       .. function ()
      return { status = 405 }
    end,
    POST = Decorators.param_is_serial "project"
        .. function ()
      return { status = 405 }
    end,
  })

  app:match ("/projects/:project/stars(/)", respond_to {
    HEAD = Decorators.param_is_project "project"
        .. function ()
      return {
        status = 204,
      }
    end,
    GET = Decorators.param_is_project "project"
       .. function (self)
      local stars = self.project:get_stars () or {}
      return {
        status = 200,
        json   = stars,
      }
    end,
    PUT = Decorators.param_is_project "project"
       .. Decorators.is_authentified
       .. function (self)
      local exists = Model.stars:find {
        user_id    = self.authentified.id,
        project_id = self.project.id,
      }
      if exists then
        return {
          status = 202,
        }
      end
      Model.stars:create {
        user_id    = self.authentified.id,
        project_id = self.project.id,
      }
      return {
        status = 201,
      }
    end,
    DELETE = Decorators.param_is_project "project"
          .. Decorators.is_authentified
          .. function (self)
      local exists = Model.stars:find {
        user_id    = self.authentified.id,
        project_id = self.project.id,
      }
      if not exists then
        return {
          status = 202,
        }
      end
      exists:delete ()
      return {
        status = 204,
      }
    end,
    OPTIONS = Decorators.param_is_serial "project"
           .. function ()
      return { status = 204 }
    end,
    PATCH = Decorators.param_is_serial "project"
       .. function ()
      return { status = 405 }
    end,
    POST = Decorators.param_is_serial "project"
        .. function ()
      return { status = 405 }
    end,
  })

end
