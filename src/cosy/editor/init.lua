local Lapis      = require "lapis"
local respond_to = require "lapis.application".respond_to
local app        = Lapis.Application ()

app.layout = false

-- app.handle_error = function ()
--   return { status = 500 }
-- end
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
