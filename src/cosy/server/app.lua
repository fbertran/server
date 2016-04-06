local Lapis  = require "lapis"
local Config = require "lapis.config".get ()
local app    = Lapis.Application ()

-- app:before_filter (function ()
    -- local after_dispatch = require "lapis.nginx.context".after_dispatch
    -- local to_json        = require "lapis.util".to_json
--   after_dispatch (function ()
--     print (to_json (_G.ngx.ctx.performance))
--   end)
-- end)

app.handle_404 = function ()
  return {
    status = 404,
    layout = false,
  }
end

app.handle_error = function (_, err, trace)
  print (err, trace)
  return {
    status = 500,
    layout = false,
  }
end

app:get ("/", function ()
  return {
    json = {
      captcha = {
        public_key = Config.captcha.public_key,
      },
    }
  }
end)

return app
