local Config      = require "lapis.config".get ()
local Database    = require "lapis.db"
local respond_to  = require "lapis.application".respond_to
local Decorators  = require "cosy.server.decorators"
local Et          = require "etlua"
local Url         = require "socket.url"
local Util        = require "cosy.util"
local _, Qless    = pcall (require, "resty.qless")
local _, Wsclient = pcall (require, "resty.websocket.client")

return function (app)

  app:match ("/projects/:project/resources/:resource/editor", respond_to {
    HEAD = Decorators.exists {} ..
           Decorators.can_read ..
           function ()
      return { status = 204 }
    end,
    OPTIONS = Decorators.exists {} ..
              Decorators.can_read ..
              function ()
      return { status = 204 }
    end,
    GET = Decorators.exists {} ..
          Decorators.can_read ..
          function (self)
      local qless  = Qless.new {
        host = Config.redis.host,
        port = Config.redis.port,
        db   = Config.redis.database,
      }
      for _ = 1, 10 do
        if self.resource.editor_url then
          local client = Wsclient:new ()
          if client:connect (self.resource.editor_url, {
            protocols = "cosy",
          }) then
            client:close ()
            _G.ngx.var._url = self.resource.editor_url:gsub ("^ws", "http")
            return { status = 200 }
          else
            local job = qless.jobs:get (self.resource.editor_job)
            job:cancel ()
            self.resource:update ({
              editor_url = Database.NULL,
              editor_job = Database.NULL,
            }, { timestamp = false })
          end
        elseif self.resource.editor_job then
          _G.ngx.sleep (1) -- FIXME
        else
          Database.query [[BEGIN]]
          self.resource:refresh ("editor_url", "editor_job")
          if self.resource.editor_job then
            Database.query [[ROLLBACK]]
          else
            local queue = qless.queues ["editors"]
            local jid   = queue:put ("cosy.editor.task", {
              token = Util.make_token (Et.render ("/projects/<%- project %>", {
                project  = self.project.id,
              }), {
                project  = self.project.id,
                resource = self.resource.id,
                api      = Et.render ("http://<%- host %>:<%- port %>/projects/<%- project %>/resources/<%- resource %>", {
                  host     = os.getenv "NGINX_HOST",
                  port     = os.getenv "NGINX_PORT",
                  project  = self.project.id,
                  resource = self.resource.id,
                }),
              }),
            })
            self.resource:update ({
              editor_job = jid,
            }, { timestamp = false })
            Database.query [[COMMIT]]
          end
        end
        self.resource:refresh ("editor_url", "editor_job")
      end
      return { status = 409 }
    end,
    PATCH = Decorators.exists {} ..
            Decorators.is_authentified ..
            function (self)
      if self.identity.type   ~= "project"
      or self.authentified.id ~= self.project.id then
        return { status = 403 }
      end
      if not Url.parse (self.json.editor_url).host then
        return { status = 400 }
      end
      self.resource:update ({
        editor_url = self.json.editor_url,
      }, { timestamp = false })
      return { status = 204 }
    end,
    DELETE = Decorators.exists {} ..
             Decorators.is_authentified ..
             function (self)
      if self.identity.type   ~= "project"
      or self.authentified.id ~= self.project.id then
        return { status = 403 }
      end
      self.resource:update ({
        editor_url = Database.NULL,
        editor_job = Database.NULL,
      }, { timestamp = false })
      return { status = 204 }
    end,
    POST = Decorators.exists {} ..
           function ()
      return { status = 405 }
    end,
    PUT = Decorators.exists {} ..
          function ()
      return { status = 405 }
    end,
  })

end
