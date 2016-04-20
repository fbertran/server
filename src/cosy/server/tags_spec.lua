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

  describe ("route '/tags'", function ()

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
        status = request (app, "/projects/" .. result.id .. "/tags/" .. key, {
          method  = "PUT",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 201)
        status = request (app, "/projects/" .. result.id .. "/tags/shared", {
          method  = "PUT",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 201)
      end
    end)

    it ("answers to HEAD", function ()
      local status = request (app, "/tags", {
        method = "HEAD",
      })
      assert.are.same (status, 204)
    end)

    it ("answers to GET", function ()
      local status, result = request (app, "/tags", {
        method = "GET",
      })
      assert.are.same (status, 200)
      result = Util.from_json (result)
      assert.are.equal (#result, 3)
    end)

    it ("answers to OPTIONS", function ()
      local status = request (app, "/tags", {
        method = "OPTIONS",
      })
      assert.are.same (status, 204)
    end)

    for _, method in ipairs { "DELETE", "PATCH", "POST", "PUT" } do
      it ("does not answer to " .. method, function ()
        local status = request (app, "/tags", {
          method = method,
        })
        assert.are.same (status, 405)
      end)
    end

  end)

  describe ("route '/tags/:tag'", function ()

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
        status = request (app, "/projects/" .. result.id .. "/tags/" .. key, {
          method  = "PUT",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 201)
        status = request (app, "/projects/" .. result.id .. "/tags/shared", {
          method  = "PUT",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 201)
      end
    end)

    it ("answers to HEAD for a non-existing tag", function ()
      local status = request (app, "/tags/unknown", {
        method = "HEAD",
      })
      assert.are.same (status, 404)
    end)

    it ("answers to HEAD for an existing tag", function ()
      local status = request (app, "/tags/rahan", {
        method = "HEAD",
      })
      assert.are.same (status, 204)
    end)

    it ("answers to GET for a non-existing tag", function ()
      local status = request (app, "/tags/unknown", {
        method = "GET",
      })
      assert.are.same (status, 404)
    end)

    it ("answers to GET for an existing tag", function ()
      local status, result = request (app, "/tags/rahan", {
        method = "GET",
      })
      assert.are.same (status, 200)
      result = Util.from_json (result)
      assert.are.equal (#result, 1)
    end)

    it ("answers to OPTIONS", function ()
      local status = request (app, "/tags/rahan", {
        method = "OPTIONS",
      })
      assert.are.same (status, 204)
    end)

    for _, method in ipairs { "DELETE", "PATCH", "POST", "PUT" } do
      it ("does not answer to " .. method, function ()
        local status = request (app, "/tags/rahan", {
          method = method,
        })
        assert.are.same (status, 405)
      end)
    end
  end)

end)
