local Test = require "cosy.server.test"

describe ("route /projects", function ()

  Test.environment.use ()

  local app, request

  before_each (function ()
    Test.clean_db ()
    request = Test.environment.request ()
    app     = Test.environment.app     ()
  end)

  before_each (function ()
    local token  = Test.make_token (Test.identities.rahan)
    local status = request (app, "/projects", {
      method  = "POST",
      headers = {
        Authorization = "Bearer " .. token,
      },
    })
    assert.are.same (status, 201)
  end)

  describe ("accessed as", function ()

    describe ("an existing collection", function ()

      describe ("without authentication", function ()

        for _, method in ipairs { "HEAD", "OPTIONS" } do
          it ("answers to " .. method, function ()
            local status = request (app, "/projects", {
              method = method,
            })
            assert.are.same (status, 204)
          end)
        end

        for _, method in ipairs { "GET" } do
          it ("answers to " .. method, function ()
            local status = request (app, "/projects", {
              method = method,
            })
            assert.are.same (status, 200)
          end)
        end

        it ("answers to POST", function ()
          local status = request (app, "/projects", {
            method  = "POST",
          })
          assert.are.same (status, 401)
        end)

        for _, method in ipairs { "DELETE", "PATCH", "PUT" } do
          it ("answers to " .. method, function ()
            local status = request (app, "/projects", {
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
            local status = request (app, "/projects", {
              method  = method,
              headers = { Authorization = "Bearer " .. token},
            })
            assert.are.same (status, 204)
          end)
        end

        for _, method in ipairs { "GET" } do
          it ("answers to " .. method, function ()
            local token  = Test.make_token (Test.identities.rahan)
            local status = request (app, "/projects", {
              method  = method,
              headers = { Authorization = "Bearer " .. token},
            })
            assert.are.same (status, 200)
          end)
        end

        for _, method in ipairs { "POST" } do
          it ("answers to " .. method, function ()
            local token  = Test.make_token (Test.identities.rahan)
            local status = request (app, "/projects", {
              method  = method,
              headers = { Authorization = "Bearer " .. token},
            })
            assert.are.same (status, 201)
          end)
        end

        for _, method in ipairs { "DELETE", "PATCH", "PUT" } do
          it ("answers to " .. method, function ()
            local token  = Test.make_token (Test.identities.rahan)
            local status = request (app, "/projects", {
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
            local status = request (app, "/projects", {
              method  = method,
              headers = { Authorization = "Bearer " .. token},
            })
            assert.are.same (status, 401)
          end)
        end

      end)

    end)

  end)

end)
