local Test = require "cosy.server.test"

describe ("route /tags/:tag", function ()
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

  before_each (function ()
    local result
    local token  = Test.make_token (Test.identities.rahan)
    local status = request (app, "/users", {
      method  = "POST",
      headers = { Authorization = "Bearer " .. token},
    })
    assert.are.same (status, 201)
    status, result = request (app, "/projects", {
      method  = "POST",
      headers = { Authorization = "Bearer " .. token},
    })
    assert.are.same (status, 201)
    result = Util.from_json (result)
    status = request (app, "/projects/" .. result.id .. "/tags/rahan", {
      method  = "PUT",
      headers = { Authorization = "Bearer " .. token},
    })
    assert.are.same (status, 201)
  end)

  describe ("accessed as", function ()

    describe ("a non-existing resource", function ()

      for _, method in ipairs { "HEAD", "OPTIONS" } do
        it ("answers to " .. method, function ()
          local status = request (app, "/tags/crao", {
            method = method,
          })
          assert.are.same (status, 404)
        end)
      end

      for _, method in ipairs { "GET" } do
        it ("answers to " .. method, function ()
          local status = request (app, "/tags/crao", {
            method = method,
          })
          assert.are.same (status, 404)
        end)
      end

      for _, method in ipairs { "DELETE", "PATCH", "POST", "PUT" } do
        it ("answers to " .. method, function ()
          local status = request (app, "/tags/crao", {
            method = method,
          })
          assert.are.same (status, 405)
        end)
      end

    end)

    describe ("an existing resource", function ()

      for _, method in ipairs { "HEAD", "OPTIONS" } do
        it ("answers to " .. method, function ()
          local status = request (app, "/tags/rahan", {
            method = method,
          })
          assert.are.same (status, 204)
        end)
      end

      for _, method in ipairs { "GET" } do
        it ("answers to " .. method, function ()
          local status, result = request (app, "/tags/rahan", {
            method = method,
          })
          assert.are.same (status, 200)
          result = Util.from_json (result)
          assert.are.equal (#result, 1)
        end)
      end

      for _, method in ipairs { "DELETE", "PATCH", "POST", "PUT" } do
        it ("answers to " .. method, function ()
          local status = request (app, "/tags/rahan", {
            method = method,
          })
          assert.are.same (status, 405)
        end)
      end

    end)

  end)

end)
