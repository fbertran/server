local Config     = require "lapis.config".get ()
local respond_to = require "lapis.application".respond_to
local Util       = require "lapis.util"
local Decorators = require "cosy.server.decorators"
local Channels   = require "cosy.taskqueue.channels"
local Redis      = require "resty.redis"
local Http       = require "resty.http"
local Et         = require "etlua"
local Jwt        = require "jwt"
local Time       = require "socket".gettime
local Url        = require "socket.url"

return function (app)

  local function make_token (sub, contents)
    local claims = {
      iss = "https://cosyverif.eu.auth0.com",
      sub = sub,
      aud = Config.auth0.client_id,
      exp = Time () + 365 * 24 * 3600,
      iat = Time (),
      contents = contents,
    }
    return Jwt.encode (claims, {
      alg = "HS256",
      keys = { private = Config.auth0.client_secret },
    })
  end

  app:match ("/projects/:project/resources/:resource", respond_to {
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
      local pubsub = Redis:new ()
      local redis  = Redis:new ()

      for _, r in ipairs { pubsub, redis } do
        local ok = r:connect (Config.redis.host, Config.redis.port)
        if not ok then
          return { status = 500 }
        end
        r:select (Config.redis.database)
      end

      local key = Et.render ("/projects/<%- project %>/resources/<%- resource %>", {
        project  = self.project.id,
        resource = self.resource.id,
      })
      assert (pubsub:subscribe (key))

      local state = redis:get (key)
      state = state ~= _G.ngx.null and Util.from_json (state) or nil

      do -- if editor is closing, wait until it is finished
        if state and state.status == "closing" then
          for message in function () return pubsub:read_reply () end do
            message.kind    = message.kind    or message [1]
            message.channel = message.channel or message [2]
            message.payload = message.payload or message [3]
            if  message.kind    == "message"
            and message.channel == key then
              local payload = message.payload and Util.from_json (message.payload)
              if payload and payload.status == "finished" then
                break
              end
            end
          end
        end
      end

      if state and state.status == "started" then
        local parts  = Url.parse (state.url)
        local client = Http.new ()
        if not client:connect (parts.host, parts.port) then
          state = nil
          redis:del (key)
        end
      end

      if not state or state.status ~= "started" then
        -- try to set status as "opening", and request editor launch
        if redis:setnx (key, Util.to_json {
          status = "opening",
        }) == 1 then
          redis:expire (key, Config.editor.sleep_timeout)
          redis:publish (Channels.edition, Util.to_json {
            token = make_token (Et.render ("/projects/<%- project %>", {
              project = self.project.id,
            }), {
              api      = Et.render ("http://api.<%- host %>:<%- port %>/", {
                host = os.getenv "NGINX_HOST",
                port = os.getenv "NGINX_PORT",
              }),
              url      = Et.render ("http://api.<%- host %>:<%- port %>" .. key, {
                host = os.getenv "NGINX_HOST",
                port = os.getenv "NGINX_PORT",
              }),
              key      = key,
              project  = self.project.id,
              resource = self.resource.id,
            })
          })
        end
      end

      if not state or state.status ~= "started" then
        -- if editor is opening, wait until it is running
        state = redis:get (key)
        state = state ~= _G.ngx.null and Util.from_json (state) or nil
        if state and state.status == "opening" then
          for message in function () return pubsub:read_reply () end do
            message.kind    = message.kind    or message [1]
            message.channel = message.channel or message [2]
            message.payload = message.payload or message [3]
            if message.channel == key and message.kind == "message" then
              local payload = message.payload and Util.from_json (message.payload)
              if payload and payload.status == "started" then
                break
              elseif payload and payload.status == "finished" then
                return { status = 404 }
              end
            end
          end
        end
      end

      if not state or state.status ~= "started" then
        state = redis:get (key)
        state = state ~= _G.ngx.null and Util.from_json (state) or nil
      end

      redis :close ()
      pubsub:close ()

      if not state or state.status ~= "started" then
        return { status = 404 }
      end

      -- redirect to editor
      _G.ngx.var._url = state.url
      return {
        status = 200,
        json   = state.url:gsub ("wss?://", "http://"),
      }
    end,
    DELETE = Decorators.exists {} ..
             function ()
      return { status = 405 }
    end,
    PATCH = Decorators.exists {} ..
            function ()
      return { status = 405 }
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
