local respond_to = require "lapis.application".respond_to
local Model      = require "cosy.server.model"
local Util       = require "lapis.util"

return function (app)

  app:match ("/users(/)", respond_to {
    GET = function ()
      local users = {}
      for i, user in ipairs (Model.users:select ()) do
        users [i] = {
          id = user.id,
        }
      end
      return {
        status = 200,
        json   = users,
      }
    end,
    POST = function (self)
      if not self.token then
        return {
          status = 401,
        }
      end
      local id   = self.token.sub
      local user = Model.users:find (id)
      if user then
        return {
          status = 409,
        }
      end
      Model.users:create {
        id = id,
      }
      return {
        status = 201,
      }
    end,
    OPTIONS = function ()
      return { status = 200 }
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
    GET = function (self)
      local id   = Util.unescape (self.params.user)
      local user = Model.users:find (id)
      if not user then
        return {
          status = 404,
        }
      end
      local info, status = app.auth0 ("/users/" .. Util.escape (id))
      if status ~= 200 then
        return {
          status = 500,
        }
      end
      local projects = {}
      for i, project in ipairs (Model.projects:find {
        user = id,
      } or {}) do
        projects [i] = {
          id = project.id,
        }
      end
      return {
        status = 200,
        json   = {
          id       = user.id,
          name     = info.name,
          nickname = info.nickname,
          company  = info.company,
          location = info.location,
          avatar   = info.picture,
          projects = projects,
        },
      }
    end,
    PATCH = function (self)
      local id = Util.unescape (self.params.user)
      if not self.token then
        return {
          status = 401,
        }
      end
      if self.token.sub ~= id then
        return {
          status = 403,
        }
      end
      local user = Model.users:find (id)
      if not user then
        return {
          status = 404,
        }
      end
      -- TODO
      return {
        status = 204,
      }
    end,
    DELETE = function (self)
      local id = Util.unescape (self.params.user)
      if not self.token then
        return {
          status = 401,
        }
      end
      if self.token.sub ~= id then
        return {
          status = 403,
        }
      end
      local user = Model.users:find (id)
      if not user then
        return {
          status = 404,
        }
      end
      user:delete ()
      return {
        status = 204,
      }
    end,
    OPTIONS = function ()
      return { status = 200 }
    end,
    PUT = function ()
      return { status = 405 }
    end,
    POST = function ()
      return { status = 405 }
    end,
  })

end
