local Jwt    = require "jwt"
local Config = require "lapis.config".get ()
local Time   = require "socket".gettime
local Db     = require "lapis.db"

local environments = {
  -- mock = {
  --   app     = require "cosy.server.app",
  --   use     = require "lapis.spec".use_test_env,
  --   request = require "lapis.spec.request".mock_request,
  -- },
  server = {
    app     = nil,
    use     = require "lapis.spec".use_test_server,
    request = function (_, ...)
      return require "lapis.spec.server".request (...)
    end,
  },
}

for name, environment in pairs (environments) do
  local request = environment.request
  local app     = environment.app

  describe ("cosyverif api in " .. name .. " mode", function ()
    environment.use ()

    before_each (function ()
      Db.delete "users"
      Db.delete "projects"
    end)

    describe ("route '/'", function ()

      it ("answers to HEAD", function ()
        local status = request (app, "/")
        assert.are.same (status, 200)
      end)

      it ("answers to GET", function ()
        local status = request (app, "/")
        assert.are.same (status, 200)
      end)

      it ("answers to OPTIONS", function ()
        local status = request (app, "/")
        assert.are.same (status, 200)
      end)

      for _, method in ipairs { "DELETE", "POST", "PUT" } do
        it ("does not answer to " .. method, function ()
          local status = request (app, "/", {
            method = method,
          })
          assert.are.same (status, 405)
        end)
      end

    end)

    describe ("route '/users'", function ()

      it ("answers to HEAD", function ()
        local status = request (app, "/users")
        assert.are.same (status, 200)
      end)

      it ("answers to GET", function ()
        local status = request (app, "/users")
        assert.are.same (status, 200)
      end)

      it ("answers to OPTIONS", function ()
        local status = request (app, "/users")
        assert.are.same (status, 200)
      end)

      it ("answers to POST without Authorization", function ()
        local status = request (app, "/users", {
          method = "POST",
        })
        assert.are.same (status, 401)
      end)

      it ("answers to POST with wrong Authorization", function ()
        local claims = {
          iss = "https://cosyverif.eu.auth0.com",
          sub = "github|1818862",
          aud = Config.auth0.client_id,
          exp = Time () + 10 * 3600,
          iat = Time (),
        }
        local token = Jwt.encode (claims, {
          alg = "HS256",
          keys = { private = "abcde" }
        })
        local status = request (app, "/users", {
          method  = "POST",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 401)
      end)

      it ("answers to POST with Authorization", function ()
        local claims = {
          iss = "https://cosyverif.eu.auth0.com",
          sub = "github|1818862",
          aud = Config.auth0.client_id,
          exp = Time () + 10 * 3600,
          iat = Time (),
        }
        local token = Jwt.encode (claims, {
          alg = "HS256",
          keys = { private = Config.auth0.client_secret }
        })
        local status = request (app, "/users", {
          method  = "POST",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 201)
      end)

      for _, method in ipairs { "DELETE", "PUT" } do
        it ("does not answer to " .. method, function ()
          local status = request (app, "/users", {
            method = method,
          })
          assert.are.same (status, 405)
        end)
      end

    end)

  end)

end
