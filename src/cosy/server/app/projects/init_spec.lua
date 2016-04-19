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

end)
