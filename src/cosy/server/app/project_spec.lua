local Jwt    = require "jwt"
local Config = require "lapis.config".get ()
local Time   = require "socket".gettime
local Ltn12  = require "ltn12"
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

    describe ("route '/projects'", function ()

      it ("answers to HEAD", function ()
        local status = request (app, "/projects", {
          method = "HEAD",
        })
        assert.are.same (status, 200)
      end)

      it ("answers to GET", function ()
        local status = request (app, "/projects", {
          method = "GET",
        })
        assert.are.same (status, 200)
      end)

      it ("answers to OPTIONS", function ()
        local status = request (app, "/projects", {
          method = "OPTIONS",
        })
        assert.are.same (status, 200)
      end)

      it ("answers to POST without Authorization", function ()
        local status = request (app, "/projects", {
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
        local status = request (app, "/projects", {
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
        status, result = request (app, "/projects", {
          method  = "POST",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 200)
        result = Util.from_json (result)
        assert.is.not_nil (result.id)
      end)

      for _, method in ipairs { "DELETE", "PATCH", "PUT" } do
        it ("does not answer to " .. method, function ()
          local status = request (app, "/projects", {
            method = method,
          })
          assert.are.same (status, 405)
        end)
      end

    end)

    describe ("route '/projects/:project'", function ()

      local projects = {}

      before_each (function ()
        for key, id in pairs (identities) do
          local token  = make_token (id)
          local status, result = request (app, "/users", {
            method  = "POST",
            headers = { Authorization = "Bearer " .. token},
          })
          assert.are.same (status, 200)
          result = Util.from_json (result)
          assert.is.not_nil (result.id)
          status, result = request (app, "/projects", {
            method  = "POST",
            headers = { Authorization = "Bearer " .. token},
          })
          assert.are.same (status, 200)
          result = Util.from_json (result)
          assert.is.not_nil (result.id)
          projects [key] = result.id
        end
      end)

      it ("answers to HEAD for a non-existing project", function ()
        local token  = make_token (identities.rahan)
        local status = request (app, "/projects/" .. projects.rahan, {
          method  = "DELETE",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 204)
        status = request (app, "/projects/" .. projects.rahan, {
          method = "HEAD",
        })
        assert.are.same (status, 404)
      end)

      it ("answers to HEAD for an existing project", function ()
        local status = request (app, "/projects/" .. projects.rahan, {
          method = "HEAD",
        })
        assert.are.same (status, 200)
      end)

      it ("answers to GET for a non-existing project", function ()
        local token  = make_token (identities.rahan)
        local status = request (app, "/projects/" .. projects.rahan, {
          method  = "DELETE",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 204)
        status = request (app, "/projects/" .. projects.rahan, {
          method = "GET",
        })
        assert.are.same (status, 404)
      end)

      it ("answers to GET for an existing project", function ()
        local status = request (app, "/projects/" .. projects.rahan, {
          method = "GET",
        })
        assert.are.same (status, 200)
      end)

      it ("answers to PATCH with no Authorization", function ()
        local status = request (app, "/projects/" .. projects.rahan, {
          method = "PATCH",
        })
        assert.are.same (status, 401)
      end)

      it ("answers to PATCH for another user with Authorization", function ()
        local token  = make_token (identities.rahan)
        local status = request (app, "/projects/" .. projects.crao, {
          method  = "PATCH",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 403)
      end)

      it ("answers to PATCH for a non-existing project with Authorization", function ()
        local token  = make_token (identities.rahan)
        local status = request (app, "/projects/" .. projects.rahan, {
          method  = "DELETE",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 204)
        status = request (app, "/projects/" .. projects.rahan, {
          method  = "PATCH",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 404)
      end)

      it ("answers to PATCH with Authorization", function ()
        local token  = make_token (identities.rahan)
        local status = request (app, "/projects/" .. projects.rahan, {
          method  = "PATCH",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 204)
      end)

      it ("updates information on PATCH with Authorization", function ()
        local token  = make_token (identities.rahan)
        local status = request (app, "/projects/" .. projects.rahan, {
          method  = "PATCH",
          headers = {
            ["Authorization" ] = "Bearer " .. token,
            ["Content-type"  ] = "application/json",
          },
          post = Util.to_json {
            name        = "a-name",
            description = "a-description",
          }
        })
        assert.are.same (status, 204)
        local result
        status, result = request (app, "/projects/" .. projects.rahan, {
          method = "GET",
        })
        assert.are.same (status, 200)
        result = Util.from_json (result)
        assert.are.equal (result.name       , "a-name"       )
        assert.are.equal (result.description, "a-description")
      end)

      it ("answers to DELETE with no Authorization", function ()
        local status = request (app, "/projects/" .. projects.rahan, {
          method = "DELETE",
        })
        assert.are.same (status, 401)
      end)

      it ("answers to DELETE for another user with Authorization", function ()
        local token  = make_token (identities.rahan)
        local status = request (app, "/projects/" .. projects.crao, {
          method  = "DELETE",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 403)
      end)

      it ("answers to DELETE for a non-existing project with Authorization", function ()
        local token  = make_token (identities.rahan)
        local status = request (app, "/projects/" .. projects.rahan, {
          method  = "DELETE",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 204)
        status = request (app, "/projects/" .. projects.rahan, {
          method = "DELETE",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 404)
      end)

      it ("answers to DELETE with Authorization", function ()
        local token  = make_token (identities.rahan)
        local status = request (app, "/projects/" .. projects.rahan, {
          method  = "DELETE",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 204)
      end)

      it ("answers to OPTIONS", function ()
        local status = request (app, "/projects/" .. projects.rahan, {
          method = "OPTIONS",
        })
        assert.are.same (status, 200)
      end)

      for _, method in ipairs { "PUT", "POST" } do
        it ("does not answer to " .. method, function ()
          local status = request (app, "/projects/" .. projects.rahan, {
            method = method,
          })
          assert.are.same (status, 405)
        end)
      end

      for _, method in ipairs { "DELETE", "GET", "OPTIONS", "PATCH", "PUT", "POST" } do
        it ("correcly fails for invalid argument to " .. method, function ()
          local status = request (app, "/projects/invalid", {
            method = method,
          })
          assert.are.same (status, 400)
        end)
      end

    end)

  end)

end
