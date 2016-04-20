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

  describe ("route '/users'", function ()

    it ("answers to HEAD", function ()
      local status = request (app, "/users", {
        method = "HEAD",
      })
      assert.are.same (status, 204)
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
      assert.are.same (status, 204)
    end)

    it ("answers to POST without Authorization", function ()
      local status = request (app, "/users", {
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
    end)

    it ("answers to POST with Authorization and Auth0 connection", function ()
      local token  = Test.make_token (Test.identities.rahan)
      local status, result = request (app, "/users", {
        method  = "POST",
        headers = {
          Authorization = "Bearer " .. token,
          Force         = "true",
        },
      })
      assert.are.same (status, 201)
      result = Util.from_json (result)
      assert.is.not_nil (result.id)
    end)

    it ("answers to POST an existing user with Authorization", function ()
      local token  = Test.make_token (Test.identities.rahan)
      local status = request (app, "/users", {
        method  = "POST",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 201)
      status = request (app, "/users", {
        method  = "POST",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 202)
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

    local users = {}

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
        users [key] = result.id
      end
    end)

    it ("answers to HEAD for a non-existing user", function ()
      local token  = Test.make_token (Test.identities.rahan)
      local status = request (app, "/users/" .. users.rahan, {
        method  = "DELETE",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 204)
      status = request (app, "/users/" .. users.rahan, {
        method = "HEAD",
      })
      assert.are.same (status, 404)
    end)

    it ("answers to HEAD for an existing user", function ()
      local status = request (app, "/users/" .. users.rahan, {
        method = "HEAD",
      })
      assert.are.same (status, 204)
    end)

    it ("answers to GET for a non-existing existing user", function ()
      local token  = Test.make_token (Test.identities.rahan)
      local status = request (app, "/users/" .. users.rahan, {
        method  = "DELETE",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 204)
      status = request (app, "/users/" .. users.rahan, {
        method = "GET",
      })
      assert.are.same (status, 404)
    end)

    it ("answers to GET for an existing user", function ()
      local status, result = request (app, "/users/" .. users.rahan, {
        method = "GET",
      })
      assert.are.same (status, 200)
      result = Util.from_json (result)
      assert.are.same (result.nickname, "saucisson")
    end)

    it ("answers to GET for a connected user", function ()
      local token = Test.make_token (Test.identities.rahan)
      local status, result = request (app, "/users/" .. users.rahan, {
        method  = "GET",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 200)
      result = Util.from_json (result)
      assert.are.same (result.nickname, "saucisson")
    end)

    it ("answers to PATCH with no Authorization", function ()
      local status = request (app, "/users/" .. users.rahan, {
        method = "PATCH",
      })
      assert.are.same (status, 401)
    end)

    it ("answers to PATCH for another user with Authorization", function ()
      local token  = Test.make_token (Test.identities.rahan)
      local status = request (app, "/users/" .. users.crao, {
        method  = "PATCH",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 403)
    end)

    it ("answers to PATCH for a non-existing user with Authorization", function ()
      local token  = Test.make_token (Test.identities.rahan)
      local status = request (app, "/users/" .. users.rahan, {
        method  = "DELETE",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 204)
      status = request (app, "/users/" .. users.rahan, {
        method  = "PATCH",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 401)
    end)

    it ("answers to PATCH for a non-existing user with Authorization", function ()
      local token  = Test.make_token (Test.identities.rahan)
      local status = request (app, "/users/" .. users.rahan, {
        method  = "DELETE",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 204)
      token  = Test.make_token (Test.identities.crao)
      status = request (app, "/users/" .. users.rahan, {
        method  = "PATCH",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 404)
    end)

    it ("answers to PATCH with Authorization", function ()
      local token  = Test.make_token (Test.identities.rahan)
      local status = request (app, "/users/" .. users.rahan, {
        method  = "PATCH",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 204)
    end)

    it ("answers to DELETE with no Authorization", function ()
      local status = request (app, "/users/" .. users.rahan, {
        method = "DELETE",
      })
      assert.are.same (status, 401)
    end)

    it ("answers to DELETE for another user with Authorization", function ()
      local token  = Test.make_token (Test.identities.rahan)
      local status = request (app, "/users/" .. users.crao, {
        method  = "DELETE",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 403)
    end)

    it ("answers to DELETE for a non-existing user with Authorization", function ()
      local token  = Test.make_token (Test.identities.rahan)
      local status = request (app, "/users/" .. users.rahan, {
        method  = "DELETE",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 204)
      status = request (app, "/users/" .. users.rahan, {
        method  = "DELETE",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 401)
    end)

    it ("answers to DELETE for a non-existing user with Authorization", function ()
      local token  = Test.make_token (Test.identities.rahan)
      local status = request (app, "/users/" .. users.rahan, {
        method  = "DELETE",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 204)
      token  = Test.make_token (Test.identities.crao)
      status = request (app, "/users/" .. users.rahan, {
        method  = "DELETE",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 404)
    end)

    it ("answers to DELETE with Authorization", function ()
      local token  = Test.make_token (Test.identities.rahan)
      local status = request (app, "/users/" .. users.rahan, {
        method  = "DELETE",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 204)
    end)

    it ("answers to OPTIONS", function ()
      local status = request (app, "/users/" .. users.rahan, {
        method = "OPTIONS",
      })
      assert.are.same (status, 204)
    end)

    for _, method in ipairs { "PUT", "POST" } do
      it ("does not answer to " .. method, function ()
        local status = request (app, "/users/" .. users.rahan, {
          method = method,
        })
        assert.are.same (status, 405)
      end)
    end

  end)

end)
