local Lapis  = require "lapis"
local Config = require "lapis.config".get ()
local app    = Lapis.Application ()

app.layout = false

if Config._name ~= "production" then
  app.handle_error = function (_, err, trace)
    return {
      status = 500,
      headers = {
        ["Cosy-trace"] = tostring (trace),
        ["Cosy-error"] = tostring (err),
      }
     }
  end
end

app.handle_404 = function ()
  return { status = 404 }
end

app.default_route = function (self)
  print (self.req.parsed_url.path)
  return {
    status = 512,
    headers = { Path = self.req.parsed_url.path },
  }
end

require "cosy.server.auth0"    (app)
require "cosy.server.before"   (app)
require "cosy.editor.resource" (app)

return app
