local respond_to = require "lapis.application".respond_to
local Decorators = require "cosy.server.decorators"

return function (app)

  require "cosy.server.projects.tag" (app)

  app:match ("/projects/:project/tags(/)", respond_to {
    HEAD    = Decorators.exists {}
           .. Decorators.can_read
           .. function ()
      return { status = 204 }
    end,
    OPTIONS = Decorators.exists {}
           .. Decorators.can_read
           .. function ()
      return { status = 204 }
    end,
    GET     = Decorators.exists {}
           .. Decorators.can_read
           .. function (self)
      local tags = self.project:get_tags () or {}
      return {
        status = 200,
        json   = tags,
      }
    end,
    DELETE  = Decorators.exists {}
           .. Decorators.can_read
           .. function ()
      return { status = 405 }
    end,
    PATCH   = Decorators.exists {}
           .. function ()
      return { status = 405 }
    end,
    POST    = Decorators.exists {}
           .. function ()
      return { status = 405 }
    end,
    PUT     = Decorators.exists {}
           .. function ()
      return { status = 405 }
    end,
  })

end
