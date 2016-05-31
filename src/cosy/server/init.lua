local Lapis      = require "lapis"
local Config     = require "lapis.config".get ()
local respond_to = require "lapis.application".respond_to
local Model      = require "cosy.server.model"
local app        = Lapis.Application ()

require "cosy.server.auth0"    (app)
require "cosy.server.before"   (app)
require "cosy.server.tags"     (app)
require "cosy.server.users"    (app)
require "cosy.server.projects" (app)

app.layout = false

-- app.handle_error = function ()
--   return { status = 500 }
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
    local user
    if self.token then
      local id = Model.identities:find (self.token.sub)
      if id then
        user = id:get_user ()
      end
    end
    return {
      status = 200,
      json   = {
        user   = user,
        server = {
          hostname = "api." .. Config.hostname,
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

return app
