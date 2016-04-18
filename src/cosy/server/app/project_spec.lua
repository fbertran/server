local Jwt    = require "jwt"
local Config = require "lapis.config".get ()
local Time   = require "socket".gettime
local Util   = require "lapis.util"
local Test   = require "cosy.server.test"

for name, environment in pairs (Test.environments) do
  local request = environment.request
  local app     = environment.app

  describe ("cosyverif api in " .. name .. " mode", function ()
    environment.use ()

    before_each (function ()
      Test.clean_db ()
    end)

    describe ("route '/projects'", function ()

      it ("answers to HEAD", function ()
        local status = request (app, "/projects", {
          method = "HEAD",
        })
        assert.are.same (status, 204)
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
        assert.are.same (status, 204)
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
        local token  = Test.make_token (Test.identities.rahan)
        local status, result = request (app, "/users", {
          method  = "POST",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 201)
        result = Util.from_json (result)
        assert.is.not_nil (result.id)
        status, result = request (app, "/projects", {
          method  = "POST",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 201)
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
        for key, id in pairs (Test.identities) do
          local token  = Test.make_token (id)
          local status, result = request (app, "/users", {
            method  = "POST",
            headers = { Authorization = "Bearer " .. token},
          })
          assert.are.same (status, 201)
          result = Util.from_json (result)
          assert.is.not_nil (result.id)
          status, result = request (app, "/projects", {
            method  = "POST",
            headers = { Authorization = "Bearer " .. token},
          })
          assert.are.same (status, 201)
          result = Util.from_json (result)
          assert.is.not_nil (result.id)
          projects [key] = result.id
        end
      end)

      it ("answers to HEAD for a non-existing project", function ()
        local token  = Test.make_token (Test.identities.rahan)
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
        assert.are.same (status, 204)
      end)

      it ("answers to GET for a non-existing project", function ()
        local token  = Test.make_token (Test.identities.rahan)
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
        local token  = Test.make_token (Test.identities.rahan)
        local status = request (app, "/projects/" .. projects.crao, {
          method  = "PATCH",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 403)
      end)

      it ("answers to PATCH for a non-existing project with Authorization", function ()
        local token  = Test.make_token (Test.identities.rahan)
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
        local token  = Test.make_token (Test.identities.rahan)
        local status = request (app, "/projects/" .. projects.rahan, {
          method  = "PATCH",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 204)
      end)

      it ("updates information on PATCH with Authorization", function ()
        local token  = Test.make_token (Test.identities.rahan)
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
        local token  = Test.make_token (Test.identities.rahan)
        local status = request (app, "/projects/" .. projects.crao, {
          method  = "DELETE",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 403)
      end)

      it ("answers to DELETE for a non-existing project with Authorization", function ()
        local token  = Test.make_token (Test.identities.rahan)
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
        local token  = Test.make_token (Test.identities.rahan)
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
        assert.are.same (status, 204)
      end)

      for _, method in ipairs { "PUT", "POST" } do
        it ("does not answer to " .. method, function ()
          local status = request (app, "/projects/" .. projects.rahan, {
            method = method,
          })
          assert.are.same (status, 405)
        end)
      end

      for _, method in ipairs { "DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "PUT", "POST" } do
        it ("correcly fails for invalid argument to " .. method, function ()
          local status = request (app, "/projects/invalid", {
            method = method,
          })
          assert.are.same (status, 400)
        end)
      end

    end)

    describe ("route '/projects/:project/stars'", function ()

      local projects = {}

      before_each (function ()
        for key, id in pairs (Test.identities) do
          local token  = Test.make_token (id)
          local status, result = request (app, "/users", {
            method  = "POST",
            headers = { Authorization = "Bearer " .. token},
          })
          assert.are.same (status, 201)
          result = Util.from_json (result)
          assert.is.not_nil (result.id)
          status, result = request (app, "/projects", {
            method  = "POST",
            headers = { Authorization = "Bearer " .. token},
          })
          assert.are.same (status, 201)
          result = Util.from_json (result)
          assert.is.not_nil (result.id)
          projects [key] = result.id
        end
      end)

      it ("answers to HEAD for a non-existing project", function ()
        local token  = Test.make_token (Test.identities.rahan)
        local status = request (app, "/projects/" .. projects.rahan, {
          method  = "DELETE",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 204)
        status = request (app, "/projects/" .. projects.rahan .. "/stars", {
          method = "HEAD",
        })
        assert.are.same (status, 404)
      end)

      it ("answers to HEAD for an existing project", function ()
        local status = request (app, "/projects/" .. projects.rahan .. "/stars", {
          method = "HEAD",
        })
        assert.are.same (status, 204)
      end)

      it ("answers to GET for a non-existing project", function ()
        local token  = Test.make_token (Test.identities.rahan)
        local status = request (app, "/projects/" .. projects.rahan, {
          method  = "DELETE",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 204)
        status = request (app, "/projects/" .. projects.rahan .. "/stars", {
          method = "GET",
        })
        assert.are.same (status, 404)
      end)

      it ("answers to GET for an existing project", function ()
        local status = request (app, "/projects/" .. projects.rahan .. "/stars", {
          method = "GET",
        })
        assert.are.same (status, 200)
      end)

      it ("answers to PUT with no Authorization", function ()
        local status = request (app, "/projects/" .. projects.rahan .. "/stars", {
          method = "PUT",
        })
        assert.are.same (status, 401)
      end)

      it ("answers to PUT for another user with Authorization", function ()
        local token  = Test.make_token (Test.identities.rahan)
        local status = request (app, "/projects/" .. projects.rahan .. "/stars", {
          method  = "PUT",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 201)
      end)

      it ("answers to PUT for a non-existing project with Authorization", function ()
        local token  = Test.make_token (Test.identities.rahan)
        local status = request (app, "/projects/" .. projects.rahan, {
          method  = "DELETE",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 204)
        status = request (app, "/projects/" .. projects.rahan .. "/stars", {
          method  = "PUT",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 404)
      end)

      it ("answers to PUT with Authorization", function ()
        local token  = Test.make_token (Test.identities.rahan)
        local status = request (app, "/projects/" .. projects.rahan .. "/stars", {
          method  = "PUT",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 201)
      end)

      it ("answers to PUT on an existing star with Authorization", function ()
        local token  = Test.make_token (Test.identities.rahan)
        local status = request (app, "/projects/" .. projects.rahan .. "/stars", {
          method  = "PUT",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 201)
        status = request (app, "/projects/" .. projects.rahan .. "/stars", {
          method  = "PUT",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 202)
      end)

      it ("updates information on PUT with Authorization", function ()
        local token  = Test.make_token (Test.identities.rahan)
        local status = request (app, "/projects/" .. projects.rahan .. "/stars", {
          method  = "PUT",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 201)
        local result
        status, result = request (app, "/projects/" .. projects.rahan .. "/stars", {
          method = "GET",
        })
        assert.are.same (status, 200)
        result = Util.from_json (result)
        assert.are.equal (#result, 1)
      end)

      it ("answers to DELETE with no Authorization", function ()
        local status = request (app, "/projects/" .. projects.rahan .. "/stars", {
          method = "DELETE",
        })
        assert.are.same (status, 401)
      end)

      it ("answers to DELETE for another user with Authorization", function ()
        local token  = Test.make_token (Test.identities.rahan)
        local status = request (app, "/projects/" .. projects.crao .. "/stars", {
          method  = "PUT",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 201)
        status = request (app, "/projects/" .. projects.crao .. "/stars", {
          method  = "DELETE",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 204)
      end)

      it ("answers to DELETE for a non-existing project with Authorization", function ()
        local token  = Test.make_token (Test.identities.rahan)
        local status = request (app, "/projects/" .. projects.rahan, {
          method  = "DELETE",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 204)
        status = request (app, "/projects/" .. projects.rahan .. "/stars", {
          method = "DELETE",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 404)
      end)

      it ("answers to DELETE with Authorization", function ()
        local token  = Test.make_token (Test.identities.rahan)
        local status = request (app, "/projects/" .. projects.rahan .. "/stars", {
          method  = "PUT",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 201)
        status = request (app, "/projects/" .. projects.rahan .. "/stars", {
          method  = "DELETE",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 204)
      end)

      it ("answers to DELETE on a non-existing star with Authorization", function ()
        local token  = Test.make_token (Test.identities.rahan)
        local status = request (app, "/projects/" .. projects.rahan .. "/stars", {
          method  = "DELETE",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 202)
      end)

      it ("answers to OPTIONS", function ()
        local status = request (app, "/projects/" .. projects.rahan .. "/stars", {
          method = "OPTIONS",
        })
        assert.are.same (status, 204)
      end)

      for _, method in ipairs { "PATCH", "POST" } do
        it ("does not answer to " .. method, function ()
          local status = request (app, "/projects/" .. projects.rahan .. "/stars", {
            method = method,
          })
          assert.are.same (status, 405)
        end)
      end

      for _, method in ipairs { "DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "PUT", "POST" } do
        it ("correcly fails for invalid argument to " .. method, function ()
          local status = request (app, "/projects/invalid/stars", {
            method = method,
          })
          assert.are.same (status, 400)
        end)
      end

    end)

    describe ("route '/projects/:project/tags'", function ()

      local projects = {}

      before_each (function ()
        for key, id in pairs (Test.identities) do
          local token  = Test.make_token (id)
          local status, result = request (app, "/users", {
            method  = "POST",
            headers = { Authorization = "Bearer " .. token},
          })
          assert.are.same (status, 201)
          result = Util.from_json (result)
          assert.is.not_nil (result.id)
          status, result = request (app, "/projects", {
            method  = "POST",
            headers = { Authorization = "Bearer " .. token},
          })
          assert.are.same (status, 201)
          result = Util.from_json (result)
          assert.is.not_nil (result.id)
          projects [key] = result.id
        end
      end)

      it ("answers to HEAD for a non-existing project", function ()
        local token  = Test.make_token (Test.identities.rahan)
        local status = request (app, "/projects/" .. projects.rahan, {
          method  = "DELETE",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 204)
        status = request (app, "/projects/" .. projects.rahan .. "/tags", {
          method = "HEAD",
        })
        assert.are.same (status, 404)
      end)

      it ("answers to HEAD for an existing project", function ()
        local status = request (app, "/projects/" .. projects.rahan .. "/tags", {
          method = "HEAD",
        })
        assert.are.same (status, 204)
      end)

      it ("answers to GET for a non-existing project", function ()
        local token  = Test.make_token (Test.identities.rahan)
        local status = request (app, "/projects/" .. projects.rahan, {
          method  = "DELETE",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 204)
        status = request (app, "/projects/" .. projects.rahan .. "/tags", {
          method = "GET",
        })
        assert.are.same (status, 404)
      end)

      it ("answers to GET for an existing project", function ()
        local status = request (app, "/projects/" .. projects.rahan .. "/tags", {
          method = "GET",
        })
        assert.are.same (status, 200)
      end)

      it ("answers to OPTIONS", function ()
        local status = request (app, "/projects/" .. projects.rahan .. "/tags", {
          method = "OPTIONS",
        })
        assert.are.same (status, 204)
      end)

      for _, method in ipairs { "DELETE", "PATCH", "POST", "PUT" } do
        it ("does not answer to " .. method, function ()
          local status = request (app, "/projects/" .. projects.rahan .. "/tags", {
            method = method,
          })
          assert.are.same (status, 405)
        end)
      end

      for _, method in ipairs { "DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "PUT", "POST" } do
        it ("correcly fails for invalid argument to " .. method, function ()
          local status = request (app, "/projects/invalid/tags", {
            method = method,
          })
          assert.are.same (status, 400)
        end)
      end

    end)

    describe ("route '/projects/:project/tags/:tag'", function ()

      local projects = {}

      before_each (function ()
        for key, id in pairs (Test.identities) do
          local token  = Test.make_token (id)
          local status, result = request (app, "/users", {
            method  = "POST",
            headers = { Authorization = "Bearer " .. token},
          })
          assert.are.same (status, 201)
          result = Util.from_json (result)
          assert.is.not_nil (result.id)
          status, result = request (app, "/projects", {
            method  = "POST",
            headers = { Authorization = "Bearer " .. token},
          })
          assert.are.same (status, 201)
          result = Util.from_json (result)
          assert.is.not_nil (result.id)
          projects [key] = result.id
        end
      end)

      it ("answers to HEAD for a non-existing project", function ()
        local token  = Test.make_token (Test.identities.rahan)
        local status = request (app, "/projects/" .. projects.rahan, {
          method  = "DELETE",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 204)
        status = request (app, "/projects/" .. projects.rahan .. "/tags/mytag", {
          method = "HEAD",
        })
        assert.are.same (status, 404)
      end)

      it ("answers to HEAD for an existing project", function ()
        local status = request (app, "/projects/" .. projects.rahan .. "/tags/mytag", {
          method = "HEAD",
        })
        assert.are.same (status, 204)
      end)

      it ("answers to GET for a non-existing project", function ()
        local token  = Test.make_token (Test.identities.rahan)
        local status = request (app, "/projects/" .. projects.rahan, {
          method  = "DELETE",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 204)
        status = request (app, "/projects/" .. projects.rahan .. "/tags/mytag", {
          method = "GET",
        })
        assert.are.same (status, 404)
      end)

      it ("answers to GET for a missing tag", function ()
        local status = request (app, "/projects/" .. projects.rahan .. "/tags/mytag", {
          method = "GET",
        })
        assert.are.same (status, 404)
      end)

      it ("answers to GET for an existing tag", function ()
        local token  = Test.make_token (Test.identities.rahan)
        local status = request (app, "/projects/" .. projects.rahan .. "/tags/mytag", {
          method = "PUT",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 201)
        status = request (app, "/projects/" .. projects.rahan .. "/tags/mytag", {
          method = "GET",
        })
        assert.are.same (status, 200)
      end)

      it ("answers to PUT with no Authorization", function ()
        local status = request (app, "/projects/" .. projects.rahan .. "/tags/mytag", {
          method = "PUT",
        })
        assert.are.same (status, 401)
      end)

      it ("answers to PUT for another user with Authorization", function ()
        local token  = Test.make_token (Test.identities.rahan)
        local status = request (app, "/projects/" .. projects.crao .. "/tags/mytag", {
          method  = "PUT",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 403)
      end)

      it ("answers to PUT for a non-existing project with Authorization", function ()
        local token  = Test.make_token (Test.identities.rahan)
        local status = request (app, "/projects/" .. projects.rahan, {
          method  = "DELETE",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 204)
        status = request (app, "/projects/" .. projects.rahan .. "/tags/mytag", {
          method  = "PUT",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 404)
      end)

      it ("answers to PUT with Authorization", function ()
        local token  = Test.make_token (Test.identities.rahan)
        local status = request (app, "/projects/" .. projects.rahan .. "/tags/mytag", {
          method  = "PUT",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 201)
      end)

      it ("answers to PUT on an existing tag with Authorization", function ()
        local token  = Test.make_token (Test.identities.rahan)
        local status = request (app, "/projects/" .. projects.rahan .. "/tags/mytag", {
          method  = "PUT",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 201)
        status = request (app, "/projects/" .. projects.rahan .. "/tags/mytag", {
          method  = "PUT",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 202)
      end)

      it ("updates tag on PUT with Authorization", function ()
        local token  = Test.make_token (Test.identities.rahan)
        local status = request (app, "/projects/" .. projects.rahan .. "/tags/mytag", {
          method  = "PUT",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 201)
        status = request (app, "/projects/" .. projects.rahan .. "/tags/mytag", {
          method = "GET",
        })
        assert.are.same (status, 200)
      end)

      it ("answers to DELETE with no Authorization", function ()
        local status = request (app, "/projects/" .. projects.rahan .. "/tags/mytag", {
          method = "DELETE",
        })
        assert.are.same (status, 401)
      end)

      it ("answers to DELETE for another user with Authorization", function ()
        local token  = Test.make_token (Test.identities.rahan)
        local status = request (app, "/projects/" .. projects.rahan .. "/tags/mytag", {
          method  = "PUT",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 201)
        token  = Test.make_token (Test.identities.crao)
        status = request (app, "/projects/" .. projects.rahan .. "/tags/mytag", {
          method  = "DELETE",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 403)
      end)

      it ("answers to DELETE for a non-existing project with Authorization", function ()
        local token  = Test.make_token (Test.identities.rahan)
        local status = request (app, "/projects/" .. projects.rahan, {
          method  = "DELETE",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 204)
        status = request (app, "/projects/" .. projects.rahan .. "/tags/mytag", {
          method = "DELETE",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 404)
      end)

      it ("answers to DELETE with Authorization", function ()
        local token  = Test.make_token (Test.identities.rahan)
        local status = request (app, "/projects/" .. projects.rahan .. "/tags/mytag", {
          method  = "PUT",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 201)
        status = request (app, "/projects/" .. projects.rahan .. "/tags/mytag", {
          method  = "DELETE",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 204)
      end)

      it ("answers to DELETE on a non-existing tag with Authorization", function ()
        local token  = Test.make_token (Test.identities.rahan)
        local status = request (app, "/projects/" .. projects.rahan .. "/tags/mytag", {
          method  = "DELETE",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 202)
      end)

      it ("answers to OPTIONS", function ()
        local status = request (app, "/projects/" .. projects.rahan .. "/tags/mytag", {
          method = "OPTIONS",
        })
        assert.are.same (status, 204)
      end)

      for _, method in ipairs { "PATCH", "POST" } do
        it ("does not answer to " .. method, function ()
          local status = request (app, "/projects/" .. projects.rahan .. "/tags/mytag", {
            method = method,
          })
          assert.are.same (status, 405)
        end)
      end

      for _, method in ipairs { "DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "PUT", "POST" } do
        it ("correcly fails for invalid argument to " .. method, function ()
          local status = request (app, "/projects/invalid/tags/mytag", {
            method = method,
          })
          assert.are.same (status, 400)
        end)
      end

    end)

  end)

end
