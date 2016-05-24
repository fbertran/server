local respond_to  = require "lapis.application".respond_to
local json_params = require "lapis.application".json_params
local Util        = require "lapis.util"
local Model       = require "cosy.server.model"
local Decorators  = require "cosy.server.decorators"
local auth0       = require "cosy.server.users.auth0"

return function (app)

  app:match ("/users/:user", respond_to {
    HEAD = Decorators.param_is_user "user" ..
           function ()
      return {
        status = 204,
      }
    end,
    OPTIONS = Decorators.param_is_user "user" ..
              function ()
      return { status = 204 }
    end,
    GET = Decorators.param_is_user "user" ..
          function (self)
      if self.token then
        local id = Model.identities:find (self.token.sub)
        if id then
          self.authentified = id:get_user ()
        end
      end
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
      self.user.projects = self.user:get_projects () or {}
      for _, project in ipairs (self.user.projects) do
        project.stars = # project:get_stars ()
        project.tags  = project:get_tags  ()
      end
      return {
        status = 200,
        json   = self.user,
      }
    end,
    PATCH = json_params ..
            Decorators.param_is_user "user" ..
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
    DELETE = Decorators.param_is_user "user" ..
             Decorators.is_authentified ..
             function (self)
      if self.authentified.id ~= self.user.id then
        return {
          status = 403,
        }
      end
      self.user:delete ()
      return {
        status = 204,
      }
    end,
    PUT = Decorators.param_is_user "user" ..
          function ()
      return { status = 405 }
    end,
    POST = Decorators.param_is_user "user" ..
           function ()
      return { status = 405 }
    end,
  })

end
