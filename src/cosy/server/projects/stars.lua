local respond_to  = require "lapis.application".respond_to
local Model       = require "cosy.server.model"
local Decorators  = require "cosy.server.decorators"

return function (app)

  app:match ("/projects/:project/stars", respond_to {
    HEAD = Decorators.fetch_params ..
           function ()
      return {
        status = 204,
      }
    end,
    OPTIONS = Decorators.fetch_params ..
              function ()
      return { status = 204 }
    end,
    GET = Decorators.fetch_params ..
          function (self)
      local stars = self.project:get_stars () or {}
      return {
        status = 200,
        json   = stars,
      }
    end,
    PUT = Decorators.fetch_params ..
          Decorators.is_authentified ..
          function (self)
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
    DELETE = Decorators.fetch_params ..
             Decorators.is_authentified ..
             function (self)
      local exists = Model.stars:find {
        user_id    = self.authentified.id,
        project_id = self.project.id,
      }
      if not exists then
        return {
          status = 404,
        }
      end
      exists:delete ()
      return {
        status = 204,
      }
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
