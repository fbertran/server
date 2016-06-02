local Lapis  = require "lapis"
local Config = require "lapis.config".get ()
local app    = Lapis.Application ()

require "cosy.server.before"   (app)
require "cosy.editor.resource" (app)

app.layout = false

if Config._name ~= "production" then
  app.handle_error = function (_, err)
    return {
      status = 500,
      headers = {
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

return app
