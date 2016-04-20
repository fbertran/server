local respond_to  = require "lapis.application".respond_to
local Util        = require "lapis.util"
local Model       = require "cosy.server.model"
local Decorators  = require "cosy.server.decorators"

return function (app)

  app:match ("/projects/:project/tags", respond_to {
    HEAD = Decorators.param_is_project "project" ..
           function ()
      return { status = 204 }
    end,
    GET = Decorators.param_is_project "project" ..
          function (self)
      local tags = self.project:get_tags () or {}
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

  app:match ("/projects/:project/tags/(:tag)", respond_to {
    HEAD = Decorators.param_is_project "project" ..
           function ()
      return { status = 204 }
    end,
    GET = Decorators.param_is_project "project" ..
          Decorators.param_is_tag "tag" ..
          function (self)
      return {
        status = 200,
        json   = self.tag,
      }
    end,
    PUT = Decorators.is_authentified ..
          Decorators.param_is_project "project" ..
          Decorators.optional (Decorators.param_is_tag "tag") ..
          function (self)
      if self.authentified.id ~= self.project.user_id then
        return { status = 403 }
      end
      if self.tag then
        self.tag:update {}
        return { status = 204 }
      else
        Model.tags:create {
          id         = Util.unescape (self.params.tag),
          project_id = self.project.id,
        }
        return { status = 201 }
      end
    end,
    DELETE = Decorators.is_authentified ..
             Decorators.param_is_project "project" ..
             Decorators.param_is_tag "tag" ..
             function (self)
      if self.authentified.id ~= self.project.user_id then
        return { status = 403 }
      end
      self.tag:delete ()
      return { status = 204 }
    end,
    OPTIONS = Decorators.param_is_serial "project" ..
              function ()
      return { status = 204 }
    end,
    PATCH = Decorators.param_is_serial "project" ..
          function ()
      return { status = 405 }
    end,
    POST = Decorators.param_is_serial "project" ..
           function ()
      return { status = 405 }
    end,
  })

end
