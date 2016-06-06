local Config = require "lapis.config".get ()
local Jwt    = require "jwt"
local Time   = require "socket".gettime

local Util = {}

function Util.make_token (sub, contents)
  local claims = {
    iss = Config.auth0.domain,
    aud = Config.auth0.client_id,
    sub = sub,
    exp = Time () + 365 * 24 * 3600,
    iat = Time (),
    contents = contents,
  }
  return Jwt.encode (claims, {
    alg = "HS256",
    keys = { private = Config.auth0.client_secret },
  })
end

return Util
