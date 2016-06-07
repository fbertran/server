local Lapis      = require "lapis"
local Config     = require "lapis.config".get ()
local respond_to = require "lapis.application".respond_to
local Quote      = require "cosy.server.quote"
local app        = Lapis.Application ()

require "cosy.server.before"   (app)
require "cosy.server.tags"     (app)
require "cosy.server.users"    (app)
require "cosy.server.projects" (app)

app.layout = false

app.handle_error = function (_, err, _)
  return {
    status = 500,
    json = {
      error = err,
    }
  }
end

-- if Config._name == "test" then
--   app:match ("/auth0", respond_to {
--     GET = function ()
--       return { status = 200 }
--     end,
--   })
-- end

app.handle_404 = function ()
  return { status = 404 }
end

app:match ("/", respond_to {
  HEAD = function ()
    return { status = 204 }
  end,
  OPTIONS = function ()
    return { status = 204 }
  end,
  GET = function (self)
    return {
      status = 200,
      json   = {
        authentified = self.authentified,
        server = {
          hostname = "api." .. Config.hostname,
          port     = Config.port,
        },
        auth = {
          domain    = Config.auth0.domain,
          client_id = Config.auth0.client_id,
        },
      }
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

app:match ("/error", respond_to {
  HEAD = function ()
    error { quote = Quote () }
  end,
  OPTIONS = function ()
    error { quote = Quote () }
  end,
  GET = function ()
    error { quote = Quote () }
  end,
  DELETE = function ()
    error { quote = Quote () }
  end,
  PATCH = function ()
    error { quote = Quote () }
  end,
  POST = function ()
    error { quote = Quote () }
  end,
  PUT = function ()
    error { quote = Quote () }
  end,
})

return app
