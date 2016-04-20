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
      assert.are.same (status, 204)
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
      assert.are.same (status, 404)
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
        local token  = Test.make_token (Test.identities.rahan)
        local status = request (app, "/projects/invalid/tags/mytag", {
          method = method,
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 400)
      end)
    end

  end)

end)
