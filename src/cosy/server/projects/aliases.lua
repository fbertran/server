local respond_to = require "lapis.application".respond_to
local Model      = require "cosy.server.model"
local Decorators = require "cosy.server.decorators"

return function (app)

  require "cosy.server.projects.alias" (app)

  app:match ("/projects/:project/resources/:resource/aliases(/)", respond_to {
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
      local aliases = Model.aliases:select ("where resource_id = ?", self.resource.id) or {}
      local result  = {
        path    = self.resource.path .. "/aliases/",
        aliases = {},
      }
      for i, alias in ipairs (aliases) do
        result.aliases [i] = {
          id       = alias.id,
          resource = self.resource.path,
        }
      end
      return {
        status = 200,
        json   = result,
      }
    end,
    POST    = Decorators.exists {}
           .. function ()
      return { status = 405 }
    end,
    DELETE  = Decorators.exists {}
           .. function ()
      return { status = 405 }
    end,
    PATCH   = Decorators.exists {}
           .. function ()
      return { status = 405 }
    end,
    PUT     = Decorators.exists {}
           .. function ()
      return { status = 405 }
    end,
  })

end
