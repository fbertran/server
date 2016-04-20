local Test = require "cosy.server.test"
local Util = require "lapis.util"

describe ("cosyverif api", function ()
  Test.environment.use ()

  local request
  local app

  before_each (function ()
    Test.clean_db ()
    request = Test.environment.request ()
    app     = Test.environment.app ()
  end)

  describe ("route '/'", function ()

    it ("answers to HEAD", function ()
      local status = request (app, "/", {
        method = "HEAD",
      })
      assert.are.same (status, 200)
    end)

    it ("answers to GET", function ()
      local status = request (app, "/", {
        method = "GET",
      })
      assert.are.same (status, 200)
    end)

    it ("answers to GET with Authorization but not a user", function ()
      local token  = Test.make_token (Test.identities.rahan)
      local status, result = request (app, "/", {
        method  = "GET",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 200)
      result = Util.from_json (result)
      assert.is_nil (result.user)
    end)

    it ("answers to GET with Authorization", function ()
      local token  = Test.make_token (Test.identities.rahan)
      local status = request (app, "/users", {
        method  = "POST",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 201)
      local result
      status, result = request (app, "/", {
        method  = "GET",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 200)
      result = Util.from_json (result)
      assert.is_not_nil (result.user)
    end)

    it ("answers to GET a missing object", function ()
      local status = request (app, "/missing", {
        method = "GET",
      })
      assert.are.same (status, 404)
    end)

    it ("answers to OPTIONS", function ()
      local status = request (app, "/", {
        method = "OPTIONS",
      })
      assert.are.same (status, 200)
    end)

    for _, method in ipairs { "DELETE", "PATCH", "POST", "PUT" } do
      it ("does not answer to " .. method, function ()
        local status = request (app, "/", {
          method = method,
        })
        assert.are.same (status, 405)
      end)
    end

  end)

end)
