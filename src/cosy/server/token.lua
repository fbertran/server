local Cjson  = require "cjson"
Cjson.encode_empty_table = function () end -- Fix for Jwt
local Config = require "lapis.config".get ()
local Jwt    = require "jwt"
local Time   = require "socket".gettime

return function (subject, contents, duration)
  local claims = {
    iss = Config.auth0.domain,
    aud = Config.auth0.client_id,
    sub = subject,
    exp = duration and duration ~= math.huge and Time () + duration,
    iat = Time (),
    contents = contents,
  }
  return Jwt.encode (claims, {
    alg = "HS256",
    keys = { private = Config.auth0.client_secret },
  })
end
