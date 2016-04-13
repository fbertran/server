local Lapis      = require "lapis"
local Config     = require "lapis.config".get ()
local respond_to = require "lapis.application".respond_to
local app        = Lapis.Application ()

require "cosy.server.app.user" (app)

app.layout = false

app:before_filter (function (self)
  if self.req.headers ["Authorization"] then
    local jwt = require "nginx-jwt"
    jwt.auth ()
    self.user = {
      id = self.res.headers ["X-Auth-UserId"]
    }
  end
end)

app.handle_404 = function ()
  return {
    status = 404,
  }
end

app.handle_error = function (_, err, trace)
  print (err, trace)
  return {
    status = 500,
  }
end

app:match ("/", respond_to {
  GET = function ()
    return {
      status = 200,
      json   = {
        server = {
          hostname = Config.hostname,
        },
        auth = {
          domain    = Config.auth.domain,
          client_id = Config.auth.client_id,
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
