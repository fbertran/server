local Test = require "cosy.server.test"

describe ("route /", function ()
  Test.environment.use ()

  local request
  local app

  before_each (function ()
    Test.clean_db ()
    request = Test.environment.request ()
    app     = Test.environment.app ()
  end)

  describe ("without authentication", function ()

    for _, method in ipairs { "HEAD", "OPTIONS" } do
      it ("answers to " .. method, function ()
        local status = request (app, "/", {
          method = method,
        })
        assert.are.same (status, 204)
      end)
    end

    for _, method in ipairs { "GET" } do
      it ("answers to " .. method, function ()
        local status = request (app, "/", {
          method = method,
        })
        assert.are.same (status, 200)
      end)
    end

    for _, method in ipairs { "DELETE", "PATCH", "POST", "PUT" } do
      it ("does not answer to " .. method, function ()
        local status = request (app, "/", {
          method = method,
        })
        assert.are.same (status, 405)
      end)
    end

  end)

  describe ("with authentication", function ()

    before_each (function ()
      local token  = Test.make_token (Test.identities.rahan)
      local status = request (app, "/users", {
        method  = "POST",
        headers = {
          Authorization = "Bearer " .. token,
        },
      })
      assert.are.same (status, 201)
    end)

    for _, method in ipairs { "HEAD", "OPTIONS" } do
      it ("answers to " .. method, function ()
        local token  = Test.make_token (Test.identities.rahan)
        local status = request (app, "/", {
          method  = method,
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 204)
      end)
    end

    for _, method in ipairs { "GET" } do
      it ("answers to " .. method, function ()
        local token  = Test.make_token (Test.identities.rahan)
        local status = request (app, "/", {
          method  = method,
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 200)
      end)
    end

    for _, method in ipairs { "DELETE", "PATCH", "POST", "PUT" } do
      it ("does not answer to " .. method, function ()
        local token  = Test.make_token (Test.identities.rahan)
        local status = request (app, "/", {
          method  = method,
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 405)
      end)
    end

  end)

  describe ("with invalid authentication", function ()

    for _, method in ipairs { "HEAD", "OPTIONS" } do
      it ("answers to " .. method, function ()
        local token  = Test.make_token (Test.identities.crao)
        local status = request (app, "/", {
          method  = method,
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 204)
      end)
    end

    for _, method in ipairs { "GET" } do
      it ("answers to " .. method, function ()
        local token  = Test.make_token (Test.identities.crao)
        local status = request (app, "/", {
          method  = method,
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 200)
      end)
    end

    for _, method in ipairs { "DELETE", "PATCH", "POST", "PUT" } do
      it ("does not answer to " .. method, function ()
        local token  = Test.make_token (Test.identities.crao)
        local status = request (app, "/", {
          method  = method,
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 405)
      end)
    end

  end)

end)
