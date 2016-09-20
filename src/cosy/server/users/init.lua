local respond_to = require "lapis.application".respond_to
local Model      = require "cosy.server.model"

return function (app)

  require "cosy.server.users.user" (app)

  app:match ("/users(/)", respond_to {
    HEAD    = function ()
      return {
        status = 204,
      }
    end,
    OPTIONS = function ()
      return { status = 204 }
    end,
    GET     = function ()
      local users  = Model.users:select () or {}
      local result = {
        url   = "/users/",
        users = {},
      }
      for i, user in ipairs (users) do
        result.users [i] = {
          url        = user.url,
          email      = user.email,
          name       = user.name,
          nickname   = user.nickname,
          reputation = user.reputation,
          picture    = user.picture,
        }
      end
      return {
        status = 200,
        json   = result,
      }
    end,
    POST    = function ()
      return { status = 405 }
    end,
    DELETE  = function ()
      return { status = 405 }
    end,
    PATCH   = function ()
      return { status = 405 }
    end,
    PUT     = function ()
      return { status = 405 }
    end,
  })

end
