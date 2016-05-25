local respond_to  = require "lapis.application".respond_to
local Decorators  = require "cosy.server.decorators"

return function (app)

  require "cosy.server.projects.tag" (app)

  app:match ("/projects/:project/tags", respond_to {
    HEAD = Decorators.fetch_params ..
           function ()
      return { status = 204 }
    end,
    OPTIONS = Decorators.fetch_params ..
              function ()
      return { status = 204 }
    end,
    GET = Decorators.fetch_params ..
          function (self)
      local tags = self.project:get_tags () or {}
      return {
        status = 200,
        json   = tags,
      }
    end,
    DELETE = Decorators.fetch_params ..
             function ()
      return { status = 405 }
    end,
    PATCH = Decorators.fetch_params ..
            function ()
      return { status = 405 }
    end,
    POST = Decorators.fetch_params ..
           function ()
      return { status = 405 }
    end,
    PUT = Decorators.fetch_params ..
          function ()
      return { status = 405 }
    end,
  })

end
