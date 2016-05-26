local respond_to = require "lapis.application".respond_to
local Db         = require "lapis.db"
local Decorators = require "cosy.server.decorators"

return function (app)

  app:match ("/tags/:tag", respond_to {
    HEAD = Decorators.exists {} ..
           function (self)
      local tags = Db.select ("id from tags where id = ? limit 1", self.tag.id) or {}
      if #tags == 0 then
        return {
          status = 404,
        }
      end
      return {
        status = 204,
      }
    end,
    OPTIONS = Decorators.exists {} ..
              function (self)
      local tags = Db.select ("id from tags where id = ? limit 1", self.tag.id) or {}
      if #tags == 0 then
        return {
          status = 404,
        }
      end
      return {
        status = 204,
      }
    end,
    GET = Decorators.exists {} ..
          function (self)
      local tags = Db.select ("* from tags where id = ?", self.tag.id) or {}
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
    DELETE = Decorators.exists {} ..
             function ()
      return { status = 405 }
    end,
    PATCH = Decorators.exists {} ..
            function ()
      return { status = 405 }
    end,
    POST = Decorators.exists {} ..
           function ()
      return { status = 405 }
    end,
    PUT = Decorators.exists {} ..
          function ()
      return { status = 405 }
    end,
  })

end
