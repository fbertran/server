local respond_to = require "lapis.application".respond_to
local Util       = require "lapis.util"
local Model      = require "cosy.server.model"
local Decorators = require "cosy.server.decorators"

return function (app)

  app:match ("/projects/:project/tags/:tag", respond_to {
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
      local tags = Model.tags:select ("where id = ? and project_id = ?", self.tag.id, self.project.id) or {}
      Model.users:include_in (tags, "user_id")
      local result = {
        url  = self.project.url .. "/tags/" .. Util.escape (self.tag.id),
        tags = {},
      }
      for i, tag in ipairs (tags) do
        result.tags [i] = {
          id      = self.tag.id,
          user    = tag.user.url,
          project = self.project.url,
        }
      end
      return {
        status = 200,
        json   = result,
      }
    end,
    PUT     = Decorators.exists { tag = true }
           .. Decorators.can_read
           .. Decorators.is_authentified
           .. function (self)
      local tag = Model.tags:find {
        id         = self.params.tag,
        user_id    = self.authentified.id,
        project_id = self.project.id,
      }
      if tag then
        return { status = 202 }
      end
      Model.tags:create {
        id         = self.params.tag,
        user_id    = self.authentified.id,
        project_id = self.project.id,
      }
      return { status = 201 }
    end,
    DELETE  = Decorators.exists {}
           .. Decorators.can_read
           .. Decorators.is_authentified
           .. function (self)
      local tag = Model.tags:find {
        id         = self.params.tag,
        user_id    = self.authentified.id,
        project_id = self.project.id,
      }
      tag:delete ()
      return { status = 204 }
    end,
    PATCH   = Decorators.exists {}
           .. function ()
      return { status = 405 }
    end,
    POST    = Decorators.exists {}
           .. function ()
      return { status = 405 }
    end,
  })

end
