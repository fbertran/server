local respond_to  = require "lapis.application".respond_to
local json_params = require "lapis.application".json_params
local Decorators  = require "cosy.server.decorators"

return function (app)

  app:match ("/projects/:project", respond_to {
    HEAD = Decorators.fetch_params ..
           Decorators.can_read ..
           function ()
      return {
        status = 204,
      }
    end,
    OPTIONS = Decorators.fetch_params ..
              Decorators.can_read ..
              function ()
      return { status = 204 }
    end,
    GET = Decorators.fetch_params ..
          Decorators.can_read ..
          function (self)
      self.project.tags      = self.project:get_tags      () or {}
      self.project.resources = self.project:get_resources () or {}
      return {
        status = 200,
        json   = self.project,
      }
    end,
    PATCH = json_params ..
            Decorators.fetch_params ..
            Decorators.is_authentified ..
            Decorators.can_write ..
            function (self)
      self.project:update {
        name        = self.params.name,
        description = self.params.description,
      }
      return {
        status = 204,
      }
    end,
    DELETE = Decorators.fetch_params ..
             Decorators.is_authentified ..
             Decorators.can_admin ..
             function (self)
      self.project:delete ()
      return {
        status = 204,
      }
    end,
    PUT = Decorators.fetch_params ..
          function ()
      return { status = 405 }
    end,
    POST = Decorators.fetch_params ..
           function ()
      return { status = 405 }
    end,
  })

end
