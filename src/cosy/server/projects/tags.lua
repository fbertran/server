local respond_to = require "lapis.application".respond_to
local Util       = require "lapis.util"
local Decorators = require "cosy.server.decorators"
local Model      = require "cosy.server.model"

return function (app)

  require "cosy.server.projects.tag" (app)

  app:match ("/projects/:project/tags(/)", respond_to {
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
      local tags = self.project:get_tags () or {}
      Model.users:include_in (tags, "user_id"   )
      local result = {
        url  = self.project.url .. "/tags/",
        tags = {},
      }
      for i, tag in ipairs (tags) do
        result.tags [i] = {
          id      = tag.id,
          user    = tag.user.url,
          project = self.project.url,
          url     = self.project.url .. "/tags/" .. Util.escape (tag.id),
        }
      end
      return {
        status = 200,
        json   = result,
      }
    end,
    DELETE  = Decorators.exists {}
           .. Decorators.can_read
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
