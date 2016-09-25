local respond_to = require "lapis.application".respond_to
local Decorators = require "cosy.server.decorators"
local Start      = require "cosy.server.jobs.editor.start"
local Stop       = require "cosy.server.jobs.editor.stop"

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
        print ("get service ", tostring (service.id), " with ", tostring (service.editor_url))
        return { redirect_to = service.editor_url }
      end
      Start.create (self.resource)
      return { status = 202 }
    end,
    DELETE  = Decorators.exists {}
           .. Decorators.is_authentified
           .. function (self)
      if self.identity.type   ~= "project"
      or self.authentified.id ~= self.project.id then
        return { status = 403 }
      end
      Stop.create (self.resource)
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
