local respond_to = require "lapis.application".respond_to
local Util       = require "lapis.util"
local Db         = require "lapis.db"
local Decorators = require "cosy.server.decorators"
local Model      = require "cosy.server.model"

return function (app)

  app:match ("/tags/:tag", respond_to {
    HEAD    = Decorators.exists {}
           .. function ()
      return {
        status = 204,
      }
    end,
    OPTIONS = Decorators.exists {}
           .. function ()
      return {
        status = 204,
      }
    end,
    GET     = Decorators.exists {}
           .. function (self)
      local tags = Db.select ("* from tags where id = ?", self.tag.id) or {}
      Model.users   :include_in (tags, "user_id"   )
      Model.projects:include_in (tags, "project_id")
      local result = {
        url  = "/tags/" .. Util.escape (self.tag.id),
        tags = {},
      }
      for i, tag in ipairs (tags) do
        result.tags [i] = {
          id      = tag.id,
          user    = tag.user.url,
          project = tag.project.url,
        }
      end
      return {
        status = 200,
        json   = result,
      }
    end,
    DELETE  = Decorators.exists {}
           .. function ()
      return { status = 405 }
    end,
    PATCH   = Decorators.exists {}
           .. function ()
      return { status = 405 }
    end,
    POST    = Decorators.exists {}
           .. function ()
      return { status = 405 }
    end,
    PUT     = Decorators.exists {}
           .. function ()
      return { status = 405 }
    end,
  })

end
