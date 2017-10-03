local Test = require "cosy.server.test"

describe ("route /aliases/:alias", function ()
  Test.environment.use ()

  local request
  local app

  before_each (function ()
    Test.clean_db ()
    request = Test.environment.request ()
    app     = Test.environment.app ()
  end)

  describe ("fails on missing alias", function ()

    for _, method in ipairs { "HEAD", "OPTIONS", "GET", "DELETE", "PATCH", "POST", "PUT" } do
      it ("answers to " .. method, function ()
        local status = request (app, "/aliases/unknown", {
          method = method,
        })
        assert.are.same (status, 404)
      end)
    end

  end)

  describe ("redirects on existing alias", function ()

    local resource, alias

    before_each (function ()
      alias = "myalias"
      local token = Test.make_token (Test.identities.rahan)
      local status, result = request (app, "/projects", {
        method  = "POST",
        headers = {
          Authorization = "Bearer " .. token,
        },
      })
      assert.are.same (status, 201)
      status, result = request (app, result.path .. "/resources", {
        method  = "POST",
        headers = {
          Authorization = "Bearer " .. token,
        },
      })
      assert.are.same (status, 201)
      resource = result.path
      status = request (app, resource .. "/aliases/" .. alias, {
        method  = "PUT",
        headers = {
          Authorization = "Bearer " .. token,
        },
      })
      assert.are.same (status, 201)
    end)

    for _, method in ipairs { "HEAD", "OPTIONS" } do
      it ("answers to " .. method, function ()
        local status, _, headers = request (app, "/aliases/" .. alias, {
          method = method,
        })
        assert.are.same (status, 302)
        assert.is_truthy (headers.location:match (resource))
      end)
    end

    for _, method in ipairs { "GET" } do
      it ("answers to " .. method, function ()
        local status, _, headers = request (app, "/aliases/" .. alias, {
          method = method,
        })
        assert.are.same (status, 302)
        assert.is_truthy (headers.location:match (resource))
      end)
    end

    for _, method in ipairs { "DELETE", "PATCH", "POST", "PUT" } do
      it ("does not answer to " .. method, function ()
        local status = request (app, "/aliases/" .. alias, {
          method = method,
        })
        assert.are.same (status, 405)
      end)
    end

  end)

end)
