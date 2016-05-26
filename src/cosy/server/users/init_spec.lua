local Test = require "cosy.server.test"

describe ("route /users", function ()

  Test.environment.use ()

  local Util, app, request

  before_each (function ()
    Util    = require "lapis.util"
    Test.clean_db ()
    request = Test.environment.request ()
    app     = Test.environment.app     ()
  end)

  describe ("accessed as", function ()

    describe ("an existing collection", function ()

      describe ("without authentication", function ()

        for _, method in ipairs { "HEAD", "OPTIONS" } do
          it ("answers to " .. method, function ()
            local status = request (app, "/users", {
              method = method,
            })
            assert.are.same (status, 204)
          end)
        end

        for _, method in ipairs { "GET" } do
          it ("answers to " .. method, function ()
            local status = request (app, "/users", {
              method = method,
            })
            assert.are.same (status, 200)
          end)
        end

        it ("answers to POST", function ()
          local status = request (app, "/users", {
            method  = "POST",
          })
          assert.are.same (status, 401)
        end)

        for _, method in ipairs { "DELETE", "PATCH", "PUT" } do
          it ("answers to " .. method, function ()
            local status = request (app, "/users", {
              method = method,
            })
            assert.are.same (status, 405)
          end)
        end

      end)

      describe ("with unknown authentication", function ()

        for _, method in ipairs { "HEAD", "OPTIONS" } do
          it ("answers to " .. method, function ()
            local token  = Test.make_token (Test.identities.rahan)
            local status = request (app, "/users", {
              method  = method,
              headers = { Authorization = "Bearer " .. token},
            })
            assert.are.same (status, 204)
          end)
        end

        for _, method in ipairs { "GET" } do
          it ("answers to " .. method, function ()
            local token  = Test.make_token (Test.identities.rahan)
            local status = request (app, "/users", {
              method  = method,
              headers = { Authorization = "Bearer " .. token},
            })
            assert.are.same (status, 200)
          end)
        end

        it ("answers to POST", function ()
          local token  = Test.make_token (Test.identities.rahan)
          local status = request (app, "/users", {
            method  = "POST",
            headers = { Authorization = "Bearer " .. token},
          })
          assert.are.same (status, 201)
        end)

        it ("answers to POST", function ()
          local token  = Test.make_token (Test.identities.rahan)
          local status = request (app, "/users", {
            method  = "POST",
            headers = {
              Authorization = "Bearer " .. token,
              Force         = "true",
            },
          })
          assert.are.same (status, 201)
        end)

        for _, method in ipairs { "DELETE", "PATCH", "PUT" } do
          it ("answers to " .. method, function ()
            local token  = Test.make_token (Test.identities.rahan)
            local status = request (app, "/users", {
              method  = method,
              headers = { Authorization = "Bearer " .. token},
            })
            assert.are.same (status, 405)
          end)
        end

      end)

      describe ("with valid authentication", function ()

        before_each (function ()
          local token  = Test.make_token (Test.identities.rahan)
          local status = request (app, "/users", {
            method  = "POST",
            headers = { Authorization = "Bearer " .. token},
          })
          assert.are.same (status, 201)
        end)

        for _, method in ipairs { "HEAD", "OPTIONS" } do
          it ("answers to " .. method, function ()
            local token  = Test.make_token (Test.identities.rahan)
            local status = request (app, "/users", {
              method  = method,
              headers = { Authorization = "Bearer " .. token},
            })
            assert.are.same (status, 204)
          end)
        end

        for _, method in ipairs { "GET" } do
          it ("answers to " .. method, function ()
            local token  = Test.make_token (Test.identities.rahan)
            local status = request (app, "/users", {
              method  = method,
              headers = { Authorization = "Bearer " .. token},
            })
            assert.are.same (status, 200)
          end)
        end

        it ("answers to POST", function ()
          local token  = Test.make_token (Test.identities.rahan)
          local status = request (app, "/users", {
            method  = "POST",
            headers = { Authorization = "Bearer " .. token},
          })
          assert.are.same (status, 202)
        end)

        for _, method in ipairs { "DELETE", "PATCH", "PUT" } do
          it ("answers to " .. method, function ()
            local token  = Test.make_token (Test.identities.rahan)
            local status = request (app, "/users", {
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
            local status = request (app, "/users", {
              method  = method,
              headers = { Authorization = "Bearer " .. token},
            })
            assert.are.same (status, 204)
          end)
        end

        for _, method in ipairs { "GET" } do
          it ("answers to " .. method, function ()
            local token  = Test.make_token (Test.identities.crao)
            local status = request (app, "/users", {
              method  = method,
              headers = { Authorization = "Bearer " .. token},
            })
            assert.are.same (status, 200)
          end)
        end

        it ("answers to POST", function ()
          local token  = Test.make_token (Test.identities.crao)
          local status, result = request (app, "/users", {
            method  = "POST",
            headers = { Authorization = "Bearer " .. token},
          })
          assert.are.same (status, 201)
          result = Util.from_json (result)
          assert.is.not_nil (result.id)
        end)

        for _, method in ipairs { "DELETE", "PATCH", "PUT" } do
          it ("answers to " .. method, function ()
            local token  = Test.make_token (Test.identities.crao)
            local status = request (app, "/users", {
              method  = method,
              headers = { Authorization = "Bearer " .. token},
            })
            assert.are.same (status, 405)
          end)
        end

      end)

    end)

  end)

end)
