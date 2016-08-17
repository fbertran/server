local Jwt          = require "jwt"
local Time         = require "socket".gettime
local Token        = require "cosy.server.token"
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
        for _ = 1, 5 do
          local status, body, headers = mock_request (app, url, options)
          body = type (body) == "string" and body ~= "" and Util.from_json (body)
          if status ~= 503 then
            return status, body, headers
          end
        end
        return 503
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
        for _ = 1, 5 do
          local status, body, headers = Server.request (url, options)
          if status ~= 503 then
            body = type (body) == "string" and body ~= "" and Util.from_json (body)
            return status, body, headers
          end
        end
        return 503
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

Test.make_token = Token

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
  Db.delete "aliases"
  Db.delete "histories"
  Db.delete "identities"
  Db.delete "permissions"
  Db.delete "projects"
  Db.delete "resources"
  Db.delete "stars"
  Db.delete "tags"
  Db.delete "users"
end

return Test
