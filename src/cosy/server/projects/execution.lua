local Config     = require "lapis.config".get ()
local respond_to = require "lapis.application".respond_to
local Decorators = require "cosy.server.decorators"
local Hashid     = require "cosy.server.hashid"
local Stop       = require "cosy.server.jobs.editor.stop"
local Qless      = require "resty.qless"

return function (app)

  app:match ("/projects/:project/executions/:execution", respond_to {
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
      return {
        status = 200,
        json   = {
          id          = Hashid.encode (self.execution.id),
          url         = self.execution.url,
          project     = self.execution:get_project ().url,
          name        = self.execution.name,
          description = self.execution.description,
          docker      = self.execution.docker_url,
        },
      }
    end,
    PATCH   = Decorators.exists {}
           .. Decorators.can_write
           .. function (self)
      self.execution:update {
        name        = self.params.name,
        description = self.params.description,
      }
      return { status = 204 }
    end,
    DELETE  = Decorators.exists {}
           .. Decorators.can_write
           .. function (self)
      local qless = Qless.new (Config.redis)
      local start = qless.jobs:get ("start@" .. self.execution.url)
      local stop  = qless.jobs:get ("stop@"  .. self.execution.url)
      if  not self.execution.docker_url
      and not start then
        return { status = 404 }
      end
      if not stop then
        Stop.create (self.execution)
      end
      return { status = 202 }
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
