local Jwt          = require "jwt"
local Time         = require "socket".gettime
local CosyUtil     = require "cosy.util"
local Util         = require "lapis.util"
local Spec         = require "lapis.spec"
local Server       = require "lapis.spec.server"
local mock_request = require "lapis.spec.request".mock_request

local Test = {}

if os.getenv "RUN_COVERAGE" then
  Test.environment = {
    nginx   = false,
    app     = function ()
      return require "cosy.server"
    end,
    use     = function ()
      Spec.use_test_env ()
    end,
    request = function ()
      return function (app, url, options)
        options         = options         or {}
        options.headers = options.headers or {}
        if options.json then
          options.body = Util.to_json (options.json)
          options.json = nil
          options.headers ["Content-type"  ] = "application/json"
          options.headers ["Content-length"] = #options.body
        end
        options.allow_error = true
        return mock_request (app, url, options)
      end
    end,
    server = function ()
      return nil
    end,
  }
else
  Test.environment = {
    nginx   = true,
    app     = function ()
      return nil
    end,
    use     = function ()
      Spec.use_test_env    ()
      Spec.use_test_server ()
    end,
    request = function ()
      return function (_, url, options)
        options         = options         or {}
        options.headers = options.headers or {}
        if options.json then
          options.post = Util.to_json (options.json)
          options.json = nil
          options.headers ["Content-type"  ] = "application/json"
          options.headers ["Content-length"] = #options.post
        end
        return Server.request (url, options)
      end
    end,
    server = function ()
      return Server.get_current_server ()
    end,
  }
end

-- Users Rahan and Naouna are supposed to exist, whereas Crao does not exist.
Test.identities = {
  rahan  = "github|1818862",
  crao   = "google-oauth2|103410538451613086005",
  naouna = "twitter|2572672862",
}

Test.make_token = CosyUtil.make_token

function Test.make_false_token (user_id)
  local Config = require "lapis.config".get ()
  local claims = {
    iss = Config.auth0.domain,
    aud = Config.auth0.client_id,
    sub = user_id,
    exp = Time () + 10 * 3600,
    iat = Time (),
  }
  return Jwt.encode (claims, {
    alg = "HS256",
    keys = { private = Config.auth0.client_id }
  })
end

function Test.clean_db ()
  local Db = require "lapis.db"
  Db.delete "executions"
  Db.delete "history"
  Db.delete "identities"
  Db.delete "permissions"
  Db.delete "projects"
  Db.delete "resources"
  Db.delete "stars"
  Db.delete "tags"
  Db.delete "users"
end

return Test
