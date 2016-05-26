local respond_to  = require "lapis.application".respond_to
local Db          = require "lapis.db"

return function (app)

  app:match ("/tags/(:tag)", respond_to {
    HEAD = function (self)
      local id   = self.json.tag
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
    OPTIONS = function (self)
      local id   = self.json.tag
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
      local id   = self.json.tag
      local tags = Db.select ("id, project_id, created_at, updated_at from tags where id = ?", id) or {}
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
