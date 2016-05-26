local respond_to  = require "lapis.application".respond_to
local Model       = require "cosy.server.model"
local Decorators  = require "cosy.server.decorators"

return function (app)

  app:match ("/projects/:project/tags/:tag", respond_to {
    HEAD = Decorators.exists {} ..
           function ()
      return { status = 204 }
    end,
    OPTIONS = Decorators.exists {} ..
              function ()
      return { status = 204 }
    end,
    GET = Decorators.exists {} ..
          function (self)
      return {
        status = 200,
        json   = self.tag,
      }
    end,
    PUT = Decorators.exists { tag = true } ..
          Decorators.is_authentified ..
          function (self)
      local tag = Model.tags:find {
        id         = self.params.tag,
        user_id    = self.authentified.id,
        project_id = self.project.id,
      }
      if tag then
        return { status = 202 }
      end
      Model.tags:create {
        id         = self.params.tag,
        user_id    = self.authentified.id,
        project_id = self.project.id,
      }
      return { status = 201 }
    end,
    DELETE = Decorators.exists {} ..
             function (self)
      local tag = Model.tags:find {
        id         = self.params.tag,
        user_id    = self.authentified.id,
        project_id = self.project.id,
      }
      if not tag then
       return { status = 404 }
      end
      tag:delete ()
      return { status = 204 }
    end,
    PATCH = Decorators.exists {} ..
            function ()
      return { status = 405 }
    end,
    POST = Decorators.exists {} ..
           function ()
      return { status = 405 }
    end,
  })

end
