local respond_to  = require "lapis.application".respond_to
local Config      = require "lapis.config".get ()
local Util        = require "lapis.util"
local Decorators  = require "cosy.server.decorators"
local Http        = require "cosy.server.http"

return function (app)

  app:match ("/users/:user", respond_to {
    HEAD    = Decorators.exists {}
           .. function ()
      return {
        status = 204,
      }
    end,
    OPTIONS = Decorators.exists {}
           .. function ()
      return { status = 204 }
    end,
    GET     = Decorators.exists {}
           .. function (self)
      if self.authentified and self.authentified.id == self.user.id then
        local info, status = Http.json {
          url      = Config.auth0.domain .. "/api/v2/users/" .. Util.escape (self.token_data.sub),
          headers  = {
            Authorization = "Bearer " .. Config.auth0.api_token,
          },
        }
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
    PATCH   = Decorators.exists {}
           .. Decorators.is_authentified
           .. function (self)
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
    DELETE  = Decorators.exists {}
           .. Decorators.is_authentified
           .. function (self)
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
    PUT     = Decorators.exists {}
           .. function ()
      return { status = 405 }
    end,
    POST    = Decorators.exists {}
           .. function ()
      return { status = 405 }
    end,
  })

end
