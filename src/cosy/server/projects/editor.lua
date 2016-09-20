local Config     = require "lapis.config".get ()
local respond_to = require "lapis.application".respond_to
local Decorators = require "cosy.server.decorators"
local Start      = require "cosy.server.jobs.editor.start"
local Stop       = require "cosy.server.jobs.editor.stop"
local Qless      = require "resty.qless"

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
      if self.resource.editor_url then
        return { redirect_to = self.resource.editor_url }
      end
      -- FIXME: issue #6
      local qless = Qless.new (Config.redis)
      local start = qless.jobs:get ("start@" .. self.resource.url .. "/editor")
      if not start then
        Start.create (self.resource)
      end
      return { status = 202 }
    end,
    DELETE  = Decorators.exists {}
           .. Decorators.is_authentified
           .. function (self)
      local qless = Qless.new (Config.redis)
      local start = qless.jobs:get ("start@" .. self.resource.url .. "/editor")
      local stop  = qless.jobs:get ("stop@"  .. self.resource.url .. "/editor")
      if self.identity.type   ~= "project"
      or self.authentified.id ~= self.project.id then
        return { status = 403 }
      elseif not self.resource.docker_url
      and    not start then
        return { status = 404 }
      end
      if not stop then
        Stop.create (self.resource)
      end
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
