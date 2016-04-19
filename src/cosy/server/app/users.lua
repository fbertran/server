local respond_to  = require "lapis.application".respond_to
local json_params = require "lapis.application".json_params
local Util        = require "lapis.util"
local Config      = require "lapis.config".get ()
local Model       = require "cosy.server.model"
local Decorators  = require "cosy.server.decorators"
local Ltn12       = require "ltn12"
local Http        = Config._name == "test"
                and require "ssl.https"
                 or require "lapis.nginx.http"

return function (app)

  local function auth0 (url)
    local result = {}
    local _, status = Http.request {
      url      = Config.auth0.api_url .. url,
      sink     = Ltn12.sink.table (result),
      headers  = {
        Authorization = "Bearer " .. Config.auth0.api_token,
      },
    }
    return Util.from_json (table.concat (result)), status
  end

  app:match ("/users(/)", respond_to {
    HEAD = function ()
      return {
        status = 204,
      }
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
        if status ~= 200 then
          return {
            status = 500,
          }
        end
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
    OPTIONS = function ()
      return { status = 204 }
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

  app:match ("/users/:user(/)", respond_to {
    HEAD = Decorators.param_is_user "user"
        .. function ()
      return {
        status = 204,
      }
    end,
    GET = Decorators.param_is_user "user"
       .. function (self)
      local id = Util.unescape (self.params.user)
      if self.token and Model.identities:find (self.token.sub) then
        local info, status = auth0 ("/users/" .. Util.escape (id))
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
    PATCH = json_params
         .. Decorators.is_authentified
         .. Decorators.param_is_user "user"
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
    DELETE = Decorators.is_authentified
          .. Decorators.param_is_user "user"
          .. function (self)
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
    OPTIONS = function ()
      return { status = 204 }
    end,
    PUT = function ()
      return { status = 405 }
    end,
    POST = function ()
      return { status = 405 }
    end,
  })

end
