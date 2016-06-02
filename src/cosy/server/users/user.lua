local respond_to  = require "lapis.application".respond_to
local Util        = require "lapis.util"
local Decorators  = require "cosy.server.decorators"
local auth0       = require "cosy.server.users.auth0"

return function (app)

  app:match ("/users/:user", respond_to {
    HEAD = Decorators.exists {} ..
           function ()
      return {
        status = 204,
      }
    end,
    OPTIONS = Decorators.exists {} ..
              function ()
      return { status = 204 }
    end,
    GET = Decorators.exists {} ..
          function (self)
      if self.authentified and self.authentified.id == self.user.id then
        local info, status = auth0 ("/users/" .. Util.escape (self.token.sub))
        if status == 200 then
          self.user:update {
            email    = info.email,
            name     = info.name,
            nickname = info.nickname,
            picture  = info.picture,
          }
        end
      end
      return {
        status = 200,
        json   = self.user,
      }
    end,
    PATCH = Decorators.exists {} ..
            Decorators.is_authentified ..
            function (self)
      if self.authentified.id ~= self.user.id then
        return {
          status = 403,
        }
      end
      self.user:update {}
      return {
        status = 204,
      }
    end,
    DELETE = Decorators.exists {} ..
             Decorators.is_authentified ..
             function (self)
      if self.authentified.id ~= self.user.id then
        return {
          status = 403,
        }
      end
      self.user:get_identity():delete ()
      return {
        status = 204,
      }
    end,
    PUT = Decorators.exists {} ..
          function ()
      return { status = 405 }
    end,
    POST = Decorators.exists {} ..
           function ()
      return { status = 405 }
    end,
  })

end
