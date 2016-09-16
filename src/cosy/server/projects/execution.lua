local Config     = require "lapis.config".get ()
local respond_to = require "lapis.application".respond_to
local Decorators = require "cosy.server.decorators"
local Qless      = require "resty.qless"
local Job        = require "cosy.server.jobs.execution"

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
        json   = self.execution,
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
      local qless = Qless.new {
        host = Config.redis.host,
        port = Config.redis.port,
        db   = Config.redis.database,
      }
      local job = qless.jobs:get (self.execution.url)
      if job then
       job:cancel ()
       Job.cleanup (job)
       job:cancel ()
      end
      return { status = 204 }
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
