local respond_to = require "lapis.application".respond_to
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
      return {
        status = 200,
        json   = tags,
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
