local Test = require "cosy.server.test"

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
