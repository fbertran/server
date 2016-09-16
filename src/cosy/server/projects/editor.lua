local Config     = require "lapis.config".get ()
local respond_to = require "lapis.application".respond_to
local Decorators = require "cosy.server.decorators"

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
      local Qless = require "resty.qless"
      local qless = Qless.new {
        host = Config.redis.host,
        port = Config.redis.port,
        db   = Config.redis.database,
      }
      local queue = qless.queues ["editors"]
      queue:put ("cosy.server.jobs.editor", {
        project  = self.project .id,
        resource = self.resource.id,
      }, {
        jid = self.resource.url .. "/editor",
      })
      for _ = 1, 30 do
        self.resource:refresh ()
        if self.resource.editor_url then
          return { redirect_to = self.resource.editor_url }
        end
        _G.ngx.sleep (1)
      end
      return { status = 503 }
    end,
    DELETE  = Decorators.exists {}
           .. Decorators.is_authentified
           .. function (self)
      if self.identity.type   ~= "project"
      or self.authentified.id ~= self.project.id then
        return { status = 403 }
      end
      local Qless = require "resty.qless"
      local qless = Qless.new {
        host = Config.redis.host,
        port = Config.redis.port,
        db   = Config.redis.database,
      }
      local job   = qless.jobs:get (self.resource.url .. "/editor")
      if job then
        local Job = require "cosy.server.jobs.editor"
        Job.cleanup (job)
        job:cancel ()
      end
      return { status = 204 }
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
