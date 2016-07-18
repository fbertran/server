local Test = require "cosy.server.test"

describe ("route /anything-not-existing", function ()
  Test.environment.use ()

  local request
  local app

  before_each (function ()
    Test.clean_db ()
    request = Test.environment.request ()
    app     = Test.environment.app ()
  end)

  describe ("without authentication", function ()

    for _, method in ipairs { "HEAD", "DELETE", "GET", "OPTIONS", "PATCH", "POST", "PUT" } do
      it ("answers to " .. method, function ()
        local status = request (app, "/anything-not-existing", {
          method = method,
        })
        assert.are.same (status, 404)
      end)
    end

  end)

end)

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

  describe ("with forced authentication", function ()

    for _, method in ipairs { "HEAD", "OPTIONS" } do
      it ("answers to " .. method, function ()
        local token  = Test.make_token (Test.identities.rahan)
        local status = request (app, "/", {
          method  = method,
          headers = {
            Authorization = "Bearer " .. token,
            Force         = "true",
          },
        })
        assert.are.same (status, 204)
      end)
    end

    for _, method in ipairs { "GET" } do
      it ("#current answers to " .. method, function ()
        local token  = Test.make_token (Test.identities.rahan)
        local status = request (app, "/", {
          method  = method,
          headers = {
            Authorization = "Bearer " .. token,
            Force         = "true",
          },
        })
        assert.are.same (status, 200)
      end)
    end

    for _, method in ipairs { "DELETE", "PATCH", "POST", "PUT" } do
      it ("does not answer to " .. method, function ()
        local token  = Test.make_token (Test.identities.rahan)
        local status = request (app, "/", {
          method  = method,
          headers = {
            Authorization = "Bearer " .. token,
            Force         = "true",
          },
        })
        assert.are.same (status, 405)
      end)
    end

  end)

  describe ("with invalid authentication", function ()

    for _, method in ipairs { "DELETE", "HEAD", "GET", "OPTIONS", "PATCH", "POST", "PUT" } do
      it ("answers to " .. method, function ()
        local token  = Test.make_token "anything"
        local status = request (app, "/", {
          method  = method,
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 401)
      end)
    end

    for _, method in ipairs { "DELETE", "HEAD", "GET", "OPTIONS", "PATCH", "POST", "PUT" } do
      it ("answers to " .. method, function ()
        local token  = Test.make_token "github|1"
        local status = request (app, "/", {
          method  = method,
          headers = {
            Authorization = "Bearer " .. token,
            Force         = "true",
          },
        })
        assert.are.same (status, 401)
      end)
    end

    for _, method in ipairs { "DELETE", "HEAD", "GET", "OPTIONS", "PATCH", "POST", "PUT" } do
      it ("answers to " .. method, function ()
        local token  = Test.make_false_token (Test.identities.rahan)
        local status = request (app, "/", {
          method  = method,
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 401)
      end)
    end

    for _, method in ipairs { "DELETE", "HEAD", "GET", "OPTIONS", "PATCH", "POST", "PUT" } do
      it ("answers to " .. method, function ()
        local token  = Test.make_token (Test.identities.rahan)
        local status = request (app, "/", {
          method  = method,
          headers = { Authorization = "Invalid " .. token},
        })
        assert.are.same (status, 401)
      end)
    end

  end)

  describe ("error handling", function ()

    for _, method in ipairs { "DELETE", "HEAD", "GET", "OPTIONS", "PATCH", "POST", "PUT" } do
      it ("answers to " .. method, function ()
        if Test.environment.nginx then
          return -- FIXME: should not filter dependeding on environment
        end
        local status, result = request (app, "/error", {
          method  = method,
        })
        assert.are.same (status, 500)
        assert.is_truthy (result.error)
      end)
    end

  end)

end)
