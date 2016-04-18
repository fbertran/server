local Util = require "lapis.util"
local Test = require "cosy.server.test"

for name, environment in pairs (Test.environments) do
  local request = environment.request
  local app     = environment.app

  describe ("cosyverif api in " .. name .. " mode", function ()
    environment.use ()

    before_each (function ()
      Test.clean_db ()
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

  end)

end
