local respond_to = require "lapis.application".respond_to
local Util       = require "lapis.util"
local Db         = require "lapis.db"

return function (app)

  require "cosy.server.tags.tag" (app)

  app:match ("/tags(/)", respond_to {
    HEAD    = function ()
      return {
        status = 204,
      }
    end,
    GET     = function ()
      local tags = Db.select "id, count (1) as count from tags group by id" or {}
      local result = {
        url  = "/tags/",
        tags = {},
      }
      for i, tag in ipairs (tags) do
        result.tags [i] = {
          id    = tag.id,
          count = tag.count,
          url   = "/tags/" .. Util.escape (tag.id),
        }
      end
      return {
        status = 200,
        json   = result,
      }
    end,
    OPTIONS = function ()
      return { status = 204 }
    end,
    DELETE  = function ()
      return { status = 405 }
    end,
    PATCH   = function ()
      return { status = 405 }
    end,
    POST    = function ()
      return { status = 405 }
    end,
    PUT     = function ()
      return { status = 405 }
    end,
  })

end
