local Test = require "cosy.server.test"

describe ("route /tags", function ()
  Test.environment.use ()

  local request, app

  before_each (function ()
    Test.clean_db ()
    request = Test.environment.request ()
    app     = Test.environment.app ()
  end)

  local projects = {}

  before_each (function ()
    for key, id in pairs (Test.identities) do
      local token  = Test.make_token (id)
      local status, result = request (app, "/projects", {
        method  = "POST",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 201)
      assert.is.not_nil (result.id)
      local project = result.url
      projects [key] = result.id
      status = request (app, project .. "/tags/" .. key, {
        method  = "PUT",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 201)
      status = request (app, project .. "/tags/shared", {
        method  = "PUT",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 201)
    end
  end)

  describe ("without authentication", function ()

    for _, method in ipairs { "HEAD", "OPTIONS" } do
      it ("answers to " .. method, function ()
        local status = request (app, "/tags", {
          method = method,
        })
        assert.are.same (status, 204)
      end)
    end

    for _, method in ipairs { "GET" } do
      it ("answers to " .. method, function ()
        local status, result = request (app, "/tags", {
          method = method,
        })
        assert.are.same (status, 200)
        local count = 0
        for _ in pairs (Test.identities) do
          count = count + 1
        end
        assert.are.equal (#result, count+1)
      end)
    end

    for _, method in ipairs { "DELETE", "PATCH", "POST", "PUT" } do
      it ("answers to " .. method, function ()
        local status = request (app, "/tags", {
          method = method,
        })
        assert.are.same (status, 405)
      end)
    end

  end)

  describe ("with valid authentication", function ()

    for _, method in ipairs { "HEAD", "OPTIONS" } do
      it ("answers to " .. method, function ()
        local token  = Test.make_token (Test.identities.rahan)
        local status = request (app, "/tags", {
          method  = method,
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 204)
      end)
    end

    for _, method in ipairs { "GET" } do
      it ("answers to " .. method, function ()
        local token  = Test.make_token (Test.identities.rahan)
        local status, result = request (app, "/tags", {
          method  = method,
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 200)
        local count = 0
        for _ in pairs (Test.identities) do
          count = count + 1
        end
        assert.are.equal (#result, count+1)
      end)
    end

    for _, method in ipairs { "DELETE", "PATCH", "POST", "PUT" } do
      it ("answers to " .. method, function ()
        local token  = Test.make_token (Test.identities.rahan)
        local status = request (app, "/tags", {
          method  = method,
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 405)
      end)
    end

  end)

  describe ("with invalid authentication", function ()

    for _, method in ipairs { "DELETE", "HEAD", "GET", "OPTIONS", "PATCH", "POST", "PUT" } do
      it ("answers to " .. method, function ()
        local token  = Test.make_false_token (Test.identities.rahan)
        local status = request (app, "/tags", {
          method  = method,
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 401)
      end)
    end

  end)

end)
