local respond_to  = require "lapis.application".respond_to
local Util        = require "lapis.util"
local Db          = require "lapis.db"

return function (app)

  app:match ("/tags(/)", respond_to {
    HEAD = function ()
      return {
        status = 204,
      }
    end,
    GET = function ()
      local tags = Db.select "distinct created_at, updated_at, id from tags" or {}
      return {
        status = 200,
        json   = tags,
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
    POST = function ()
      return { status = 405 }
    end,
    PUT = function ()
      return { status = 405 }
    end,
  })

  app:match ("/tags/(:tag)(/)", respond_to {
    HEAD = function (self)
      local id   = Util.unescape (self.params.tag)
      local tags = Db.select ("id from tags where id = ? limit 1", id) or {}
      if #tags == 0 then
        return {
          status = 404,
        }
      end
      return {
        status = 204,
      }
    end,
    GET = function (self)
      local id   = Util.unescape (self.params.tag)
      local tags = Db.select ("distinct created_at, updated_at, id from tags where id = ?", id) or {}
      if #tags == 0 then
        return {
          status = 404,
        }
      end
      return {
        status = 200,
        json   = tags,
      }
    end,
    DELETE = function ()
      return { status = 405 }
    end,
    OPTIONS = function ()
      return { status = 204 }
    end,
    PATCH = function ()
      return { status = 405 }
    end,
    POST = function ()
      return { status = 405 }
    end,
    PUT = function ()
      return { status = 405 }
    end,
  })

end
