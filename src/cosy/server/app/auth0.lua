-- local Basexx = require "basexx"
local Cjson  = require "cjson"
Cjson.encode_empty_table = function () end -- Fix for Jwt
local Jwt    = require "jwt"
local Config = require "lapis.config".get ()

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

return function (self)
  local header = self.req.headers ["Authorization"]
  if not header then
    return nil
  end
  print ("Authorization:", header)
  local token = header:match "Bearer%s+(.+)"
  if not token then
    return nil, "missing token"
  end
  print ("Token:", token)
  local jwt, err = Jwt.decode (token, {
    keys = {
      public = Config.auth0.client_secret
    }
  })
  if not jwt then
    print ("Invalid token:",  err)
    return nil, "invalid token"
  end
  self.user = jwt
  print ("JWT: " .. Cjson.encode (jwt))
end