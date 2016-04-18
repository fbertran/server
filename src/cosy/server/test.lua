local Jwt    = require "jwt"
local Config = require "lapis.config".get ()
local Time   = require "socket".gettime
local Db     = require "lapis.db"

local Test = {}

Test.environments = {}

Test.environments.server = {
  app     = nil,
  use     = require "lapis.spec".use_test_server,
  request = function (_, ...)
    return require "lapis.spec.server".request (...)
  end,
}

-- if not os.getenv "Apple_PubSub_Socket_Render" then
--   environments.mock = {
--     app     = require "cosy.server.app",
--     use     = require "lapis.spec".use_test_env,
--     request = require "lapis.spec.request".mock_request,
--   }
-- end

Test.identities = {
  rahan = "github|1818862",
  crao  = "google-oauth2|103410538451613086005",
}

function Test.make_token (user_id)
  local claims = {
    iss = "https://cosyverif.eu.auth0.com",
    sub = user_id,
    aud = Config.auth0.client_id,
    exp = Time () + 10 * 3600,
    iat = Time (),
  }
  return Jwt.encode (claims, {
    alg = "HS256",
    keys = { private = Config.auth0.client_secret }
  })
end

function Test.clean_db ()
  Db.delete "executions"
  Db.delete "identities"
  Db.delete "projects"
  Db.delete "resources"
  Db.delete "stars"
  Db.delete "tags"
  Db.delete "users"
end

return Test
