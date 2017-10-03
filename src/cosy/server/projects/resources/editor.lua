local respond_to = require "lapis.application".respond_to
local Decorators = require "cosy.server.decorators"
local Job        = require "cosy.server.jobs.editor"

return function (app)

  app:match ("/projects/:project/resources/:resource/editor", respond_to {
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
      local service = self.resource:get_service ()
      if service and service.editor_url then
        return { redirect_to = service.editor_url }
      elseif not service then
        Job.start (self.resource)
      end
      return { status = 202 }
    end,
    DELETE  = Decorators.exists {}
           .. Decorators.is_authentified
           .. function (self)
      if self.identity.type   ~= "project"
      or self.authentified.id ~= self.project.id then
        return { status = 403 }
      end
      Job.stop (self.resource)
      return { status = 202 }
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
