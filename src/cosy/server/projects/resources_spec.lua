local Test = require "cosy.server.test"

describe ("cosyverif api", function ()
  Test.environment.use ()

  local Util
  local request
  local app

  before_each (function ()
    Util    = require "lapis.util"
    Test.clean_db ()
    request = Test.environment.request ()
    app     = Test.environment.app ()
  end)

  describe ("route '/projects/:project/resources'", function ()

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
      status = request (app, "/projects/" .. projects.rahan .. "/resources", {
        method = "HEAD",
      })
      assert.are.same (status, 404)
    end)

    it ("answers to HEAD for an existing project", function ()
      local status = request (app, "/projects/" .. projects.rahan .. "/resources", {
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
      status = request (app, "/projects/" .. projects.rahan .. "/resources", {
        method = "GET",
      })
      assert.are.same (status, 404)
    end)

    it ("answers to GET for an existing project", function ()
      local status = request (app, "/projects/" .. projects.rahan .. "/resources", {
        method = "GET",
      })
      assert.are.same (status, 200)
    end)

    it ("answers to POST for a non-existing project", function ()
      local token  = Test.make_token (Test.identities.rahan)
      local status = request (app, "/projects/" .. projects.rahan, {
        method  = "DELETE",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 204)
      status = request (app, "/projects/" .. projects.rahan .. "/resources", {
        method  = "POST",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 404)
    end)

    it ("answers to POST for an existing project and no Authorization", function ()
      local status = request (app, "/projects/" .. projects.rahan .. "/resources", {
        method  = "POST",
      })
      assert.are.same (status, 401)
    end)

    it ("answers to POST for an existing project and wrong Authorization", function ()
      local token  = Test.make_token (Test.identities.crao)
      local status = request (app, "/projects/" .. projects.rahan .. "/resources", {
        method  = "POST",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 403)
    end)

    it ("answers to POST for an existing project and Authorization", function ()
      local token  = Test.make_token (Test.identities.rahan)
      local status = request (app, "/projects/" .. projects.rahan .. "/resources", {
        method  = "POST",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 201)
    end)

    it ("answers to OPTIONS", function ()
      local status = request (app, "/projects/" .. projects.rahan .. "/resources", {
        method = "OPTIONS",
      })
      assert.are.same (status, 204)
    end)

    for _, method in ipairs { "DELETE", "PATCH", "PUT" } do
      it ("does not answer to " .. method, function ()
        local status = request (app, "/projects/" .. projects.rahan .. "/resources", {
          method = method,
        })
        assert.are.same (status, 405)
      end)
    end

    for _, method in ipairs { "DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "PUT", "POST" } do
      it ("correcly fails for invalid argument to " .. method, function ()
        local token  = Test.make_token (Test.identities.crao)
        local status = request (app, "/projects/invalid/resources", {
          headers = { Authorization = "Bearer " .. token},
          method = method,
        })
        assert.are.same (status, 400)
      end)
    end

  end)

  describe ("route '/projects/:project/resources/:resource'", function ()

    local projects  = {}
    local resources = {}

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
        status, result = request (app, "/projects/" .. result.id .. "/resources", {
          method  = "POST",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 201)
        result = Util.from_json (result)
        assert.is.not_nil (result.id)
        resources [key] = result.id
      end
    end)

    it ("answers to HEAD for a non-existing resource", function ()
      local token  = Test.make_token (Test.identities.rahan)
      local status = request (app, "/projects/" .. projects.rahan .. "/resources/" .. resources.rahan, {
        method  = "DELETE",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 204)
      status = request (app, "/projects/" .. projects.rahan .. "/resources/" .. resources.rahan, {
        method = "HEAD",
      })
      assert.are.same (status, 404)
    end)

    it ("answers to HEAD for an existing resource", function ()
      local status = request (app, "/projects/" .. projects.rahan .. "/resources/" .. resources.rahan, {
        method = "HEAD",
      })
      assert.are.same (status, 204)
    end)

    it ("answers to GET for a non-existing resource", function ()
      local token  = Test.make_token (Test.identities.rahan)
      local status = request (app, "/projects/" .. projects.rahan .. "/resources/" .. resources.rahan, {
        method  = "DELETE",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 204)
      status = request (app, "/projects/" .. projects.rahan .. "/resources/" .. resources.rahan, {
        method = "GET",
      })
      assert.are.same (status, 404)
    end)

    it ("answers to GET for an existing resource", function ()
      local status = request (app, "/projects/" .. projects.rahan .. "/resources/" .. resources.rahan, {
        method = "GET",
      })
      assert.are.same (status, 200)
    end)

    it ("answers to PUT with no Authorization", function ()
      local status = request (app, "/projects/" .. projects.rahan .. "/resources/" .. resources.rahan, {
        method = "PUT",
      })
      assert.are.same (status, 401)
    end)

    it ("answers to PUT for another user with Authorization", function ()
      local token  = Test.make_token (Test.identities.rahan)
      local status = request (app, "/projects/" .. projects.crao .. "/resources/" .. resources.crao, {
        method  = "PUT",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 403)
    end)

    it ("answers to PUT for a non-existing resource with Authorization", function ()
      local token  = Test.make_token (Test.identities.rahan)
      local status = request (app, "/projects/" .. projects.rahan .. "/resources/" .. resources.rahan, {
        method  = "DELETE",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 204)
      status = request (app, "/projects/" .. projects.rahan .. "/resources/" .. resources.rahan, {
        method  = "PUT",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 404)
    end)

    it ("answers to PUT for a non-project resource with Authorization", function ()
      local token  = Test.make_token (Test.identities.rahan)
      local status = request (app, "/projects/" .. projects.rahan .. "/resources/" .. resources.crao, {
        method  = "PUT",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 404)
    end)

    it ("answers to PUT with Authorization", function ()
      local token  = Test.make_token (Test.identities.rahan)
      local status = request (app, "/projects/" .. projects.rahan .. "/resources/" .. resources.rahan, {
        method  = "PUT",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 204)
    end)

    it ("updates resource on PUT with Authorization", function ()
      local token  = Test.make_token (Test.identities.rahan)
      local status = request (app, "/projects/" .. projects.rahan .. "/resources/" .. resources.rahan, {
        method  = "PUT",
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
      status, result = request (app, "/projects/" .. projects.rahan .. "/resources/" .. resources.rahan, {
        method = "GET",
      })
      assert.are.same (status, 200)
      result = Util.from_json (result)
      assert.are.equal (result.name, "a-name")
    end)

    it ("answers to PATCH with no Authorization", function ()
      local status = request (app, "/projects/" .. projects.rahan .. "/resources/" .. resources.rahan, {
        method = "PATCH",
      })
      assert.are.same (status, 401)
    end)

    it ("answers to PATCH for another user with Authorization", function ()
      local token  = Test.make_token (Test.identities.rahan)
      local status = request (app, "/projects/" .. projects.crao .. "/resources/" .. resources.crao, {
        method  = "PATCH",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 403)
    end)

    it ("answers to PATCH for a non-existing resource with Authorization", function ()
      local token  = Test.make_token (Test.identities.rahan)
      local status = request (app, "/projects/" .. projects.rahan .. "/resources/" .. resources.rahan, {
        method  = "DELETE",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 204)
      status = request (app, "/projects/" .. projects.rahan .. "/resources/" .. resources.rahan, {
        method  = "PATCH",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 404)
    end)

    it ("answers to PATCH for a non-project resource with Authorization", function ()
      local token  = Test.make_token (Test.identities.rahan)
      local status = request (app, "/projects/" .. projects.rahan .. "/resources/" .. resources.crao, {
        method  = "PATCH",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 404)
    end)

    it ("answers to PATCH with Authorization #current", function ()
      local token  = Test.make_token (Test.identities.rahan)
      local status = request (app, "/projects/" .. projects.rahan .. "/resources/" .. resources.rahan, {
        method  = "PATCH",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 301)
    end)

    it ("answers to DELETE with no Authorization", function ()
      local status = request (app, "/projects/" .. projects.rahan .. "/resources/" .. resources.rahan, {
        method = "DELETE",
      })
      assert.are.same (status, 401)
    end)

    it ("answers to DELETE for another user with Authorization", function ()
      local token  = Test.make_token (Test.identities.crao)
      local status = request (app, "/projects/" .. projects.rahan.. "/resources/" .. resources.rahan, {
        method  = "DELETE",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 403)
    end)

    it ("answers to DELETE for a non-existing resource with Authorization", function ()
      local token  = Test.make_token (Test.identities.rahan)
      local status = request (app, "/projects/" .. projects.rahan .. "/resources/" .. resources.rahan, {
        method  = "DELETE",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 204)
      status = request (app, "/projects/" .. projects.rahan .. "/resources/" .. resources.rahan, {
        method = "DELETE",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 404)
    end)

    it ("answers to DELETE for a non-project resource with Authorization", function ()
      local token  = Test.make_token (Test.identities.rahan)
      local status = request (app, "/projects/" .. projects.crao .. "/resources/" .. resources.rahan, {
        method = "DELETE",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 404)
    end)

    it ("answers to DELETE with Authorization", function ()
      local token  = Test.make_token (Test.identities.rahan)
      local status = request (app, "/projects/" .. projects.rahan .. "/resources/" .. resources.rahan, {
        method  = "DELETE",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 204)
    end)

    it ("answers to OPTIONS", function ()
      local status = request (app, "/projects/" .. projects.rahan .. "/resources/" .. resources.rahan, {
        method = "OPTIONS",
      })
      assert.are.same (status, 204)
    end)

    for _, method in ipairs { "POST" } do
      it ("does not answer to " .. method, function ()
        local status = request (app, "/projects/" .. projects.rahan .. "/resources/" .. resources.rahan, {
          method = method,
        })
        assert.are.same (status, 405)
      end)
    end

    for _, method in ipairs { "DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "PUT", "POST" } do
      it ("correcly fails for invalid argument to " .. method, function ()
        local token  = Test.make_token (Test.identities.rahan)
        local status = request (app, "/projects/" .. projects.rahan .. "/resources/myresource", {
          method = method,
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 400)
      end)
    end

  end)

end)
