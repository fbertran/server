local Cjson  = require "cjson"
Cjson.encode_empty_table = function () end -- Fix for Jwt
local Jwt    = require "jwt"
local Config = require "lapis.config".get ()

-- local Basexx = require "basexx"
-- local function tobase64 (secret)
--   local r = #secret % 4
--   if     r == 2 then secret = secret .. "=="
--   elseif r == 3 then secret = secret .. "="
--   end
--   secret = secret
--          : gsub ("-", "+")
--          : gsub ("_", "/")
--   return Basexx.from_base64 (secret)
-- end

return function (app)

  app:before_filter (function (self)
    local header = self.req.headers ["Authorization"]
    if not header then
      return nil
    end
    local token = header:match "Bearer%s+(.+)"
    if not token then
      self:write { status = 400 }
      return
    end
    local jwt = Jwt.decode (token, {
      keys = {
        public = Config.auth0.client_secret
      }
    })
    if not jwt then
      self:write { status = 401 }
      return
    end
    self.token = jwt
  end)

  if Config._name == "test" then
    local respond_to = require "lapis.application".respond_to
    app:match ("/auth0", respond_to {
      GET = function ()
        return { status = 200 }
      end,
    })
  end

end
