local Jwt    = require "jwt"
local Config = require "lapis.config".get ()
local Time   = require "socket".gettime
local Db     = require "lapis.db"
local Util   = require "lapis.util"
local Env    = require "cosy.server.test"

local function make_token (user_id)
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

for name, environment in pairs (Env) do
  local request = environment.request
  local app     = environment.app

  local identities = {
    rahan = "github|1818862",
    crao  = "github|199517",
  }

  describe ("cosyverif api in " .. name .. " mode", function ()
    environment.use ()

    before_each (function ()
      Db.delete "executions"
      Db.delete "identities"
      Db.delete "projects"
      Db.delete "resources"
      Db.delete "stars"
      Db.delete "tags"
      Db.delete "users"
    end)

    describe ("route '/users'", function ()

      it ("answers to HEAD", function ()
        local status = request (app, "/users", {
          method = "HEAD",
        })
        assert.are.same (status, 200)
      end)

      it ("answers to GET", function ()
        local status = request (app, "/users", {
          method = "GET",
        })
        assert.are.same (status, 200)
      end)

      it ("answers to OPTIONS", function ()
        local status = request (app, "/users", {
          method = "OPTIONS",
        })
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
          alg  = "HS256",
          keys = { private = Config.auth0.client_id }
        })
        local status = request (app, "/users", {
          method  = "POST",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 401)
      end)

      it ("answers to POST with Authorization", function ()
        local token  = make_token (identities.rahan)
        local status, result = request (app, "/users", {
          method  = "POST",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 200)
        result = Util.from_json (result)
        assert.is.not_nil (result.id)
      end)

      for _, method in ipairs { "DELETE", "PATCH", "PUT" } do
        it ("does not answer to " .. method, function ()
          local status = request (app, "/users", {
            method = method,
          })
          assert.are.same (status, 405)
        end)
      end

    end)

    describe ("route '/users/:user'", function ()

      before_each (function ()
        for _, id in pairs (identities) do
          local token  = make_token (id)
          local status = request (app, "/users", {
            method  = "POST",
            headers = { Authorization = "Bearer " .. token},
          })
          assert.are.same (status, 200)
        end
      end)

      it ("answers to HEAD for a non-existing user", function ()
        local status = request (app, "/users/non-existing", {
          method = "HEAD",
        })
        assert.are.same (status, 404)
      end)

      it ("answers to HEAD for an existing user", function ()
        local status = request (app, "/users/" .. identities.rahan, {
          method = "HEAD",
        })
        assert.are.same (status, 200)
      end)

      it ("answers to GET for a non-existing existing user", function ()
        local status = request (app, "/users/non-existing", {
          method = "GET",
        })
        assert.are.same (status, 404)
      end)

      it ("answers to GET for an existing user", function ()
        local status, result = request (app, "/users/" .. identities.rahan, {
          method = "GET",
        })
        assert.are.same (status, 200)
        result = Util.from_json (result)
        assert.are.same (result.nickname, "saucisson")
      end)

      it ("answers to PATCH with no Authorization", function ()
        local status = request (app, "/users/" .. identities.rahan, {
          method = "PATCH",
        })
        assert.are.same (status, 401)
      end)

      it ("answers to PATCH for another user with Authorization", function ()
        local token  = make_token (identities.rahan)
        local status = request (app, "/users/" .. identities.crao, {
          method  = "PATCH",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 403)
      end)

      it ("answers to PATCH for a non-existing user with Authorization", function ()
        local token  = make_token (identities.rahan)
        local status = request (app, "/users/another", {
          method  = "PATCH",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 403)
      end)

      it ("answers to PATCH with Authorization", function ()
        local token  = make_token (identities.rahan)
        local status = request (app, "/users/" .. identities.rahan, {
          method  = "PATCH",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 204)
      end)

      it ("answers to DELETE with no Authorization", function ()
        local status = request (app, "/users/" .. identities.rahan, {
          method = "DELETE",
        })
        assert.are.same (status, 401)
      end)

      it ("answers to DELETE for another user with Authorization", function ()
        local token  = make_token (identities.rahan)
        local status = request (app, "/users/" .. identities.crao, {
          method  = "DELETE",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 403)
      end)

      it ("answers to DELETE for a non-existing user with Authorization", function ()
        local token  = make_token (identities.rahan)
        local status = request (app, "/users/another", {
          method  = "DELETE",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 403)
      end)

      it ("answers to DELETE with Authorization", function ()
        local token  = make_token (identities.rahan)
        local status = request (app, "/users/" .. identities.rahan, {
          method  = "DELETE",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 204)
      end)

      it ("answers to OPTIONS", function ()
        local status = request (app, "/users/" .. identities.rahan, {
          method = "OPTIONS",
        })
        assert.are.same (status, 200)
      end)

      for _, method in ipairs { "PUT", "POST" } do
        it ("does not answer to " .. method, function ()
          local status = request (app, "/users/" .. identities.rahan, {
            method = method,
          })
          assert.are.same (status, 405)
        end)
      end

    end)

  end)

end
