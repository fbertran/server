local respond_to  = require "lapis.application".respond_to
local Util        = require "lapis.util"
local Config      = require "lapis.config".get ()
local Model       = require "cosy.server.model"
local auth0       = require "cosy.server.users.auth0"

return function (app)

  require "cosy.server.users.user" (app)

  app:match ("/users", respond_to {
    HEAD = function ()
      return {
        status = 204,
      }
    end,
    OPTIONS = function ()
      return { status = 204 }
    end,
    GET = function ()
      return {
        status = 200,
        json   = Model.users:select () or {},
      }
    end,
    POST = function (self)
      if not self.token then
        return {
          status = 401,
        }
      end
      local id   = self.token.sub
      local user = Model.identities:find (id)
      if user then
        return {
          status = 202,
        }
      end
      local info
      if Config._name == "test" and not self.req.headers ["Force"] then
        info = {
          email    = nil,
          name     = "Alban Linard",
          nickname = "saucisson",
          picture  = "https://avatars.githubusercontent.com/u/1818862?v=3",
        }
      else
        local status
        info, status = auth0 ("/users/" .. Util.escape (id))
        assert (status == 200)
      end
      user = Model.users:create {
        email    = info.email,
        name     = info.name,
        nickname = info.nickname,
        picture  = info.picture,
      }
      Model.identities:create {
        id      = id,
        user_id = user.id,
      }
      return {
        status = 201,
        json   = user,
      }
    end,
    DELETE = function ()
      return { status = 405 }
    end,
    PATCH = function ()
      return { status = 405 }
    end,
    PUT = function ()
      return { status = 405 }
    end,
  })

end
