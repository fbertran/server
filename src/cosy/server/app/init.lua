local Lapis      = require "lapis"
local Config     = require "lapis.config".get ()
local respond_to = require "lapis.application".respond_to
local app        = Lapis.Application ()

require "cosy.server.app.auth0"          (app)
require "cosy.server.app.tags"           (app)
require "cosy.server.app.users"          (app)
require "cosy.server.app.projects"       (app)
require "cosy.server.app.projects.tags"  (app)
require "cosy.server.app.projects.stars" (app)

app.layout = false

app.handle_404 = function ()
  return {
    status = 404,
  }
end

-- app.handle_error = function () -- (_, err, trace)
--   return {
--     status = 200,
--   }
-- end

app:match ("/", respond_to {
  GET = function ()
    return {
      status = 200,
      json   = {
        server = {
          hostname = Config.hostname,
        },
        auth = {
          domain    = Config.auth0.domain,
          client_id = Config.auth0.client_id,
        },
      }
    }
  end,
  OPTIONS = function ()
    return { status = 200 }
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

return app
