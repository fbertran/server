-- local Config    = require "lapis.config".get ()
-- local Et        = require "etlua"
local Test      = require "cosy.server.test"
-- local Copas     = require "copas"
-- local Websocket = require "websocket"

describe ("route /projects/:project/resources/:resource/editor", function ()

  Test.environment.use ()

  local app, project, route, request, naouna

  before_each (function ()
    Test.clean_db ()
    request = Test.environment.request ()
    app     = Test.environment.app ()
  end)

  before_each (function ()
    local token = Test.make_token (Test.identities.naouna)
    local status, result = request (app, "/", {
      method  = "GET",
      headers = { Authorization = "Bearer " .. token },
    })
    assert.are.same (status, 200)
    assert.is.not_nil (result.authentified.id)
    naouna = result.authentified.id
  end)

  before_each (function ()
    local token = Test.make_token (Test.identities.rahan)
    local status, result = request (app, "/projects", {
      method  = "POST",
      headers = {
        Authorization = "Bearer " .. token,
      },
    })
    assert.are.same (status, 201)
    assert.is.not_nil (result.id)
    project = "/projects/" .. result.id
    status, result = request (app, project .. "/resources", {
      method  = "POST",
      headers = {
        Authorization = "Bearer " .. token,
      },
    })
    assert.are.same (status, 201)
    assert.is.not_nil (result.id)
    route = project.. "/resources/" .. result.id .. "/editor"
  end)

  describe ("accessed as", function ()

    describe ("a non-existing resource", function ()

      before_each (function ()
        local token  = Test.make_token (Test.identities.rahan)
        local status = request (app, project, {
          method  = "DELETE",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 204)
      end)

      describe ("without authentication", function ()

        for _, method in ipairs { "DELETE", "HEAD", "GET", "OPTIONS", "PATCH", "POST", "PUT" } do
          it ("answers to " .. method, function ()
            local status = request (app, route, {
              method = method,
            })
            assert.are.same (status, 404)
          end)
        end

      end)

      describe ("with valid authentication", function ()

        for _, method in ipairs { "DELETE", "HEAD", "GET", "OPTIONS", "PATCH", "POST", "PUT" } do
          it ("answers to " .. method, function ()
            local token  = Test.make_token (Test.identities.rahan)
            local status = request (app, route, {
              method  = method,
              headers = { Authorization = "Bearer " .. token},
            })
            assert.are.same (status, 404)
          end)
        end

      end)

      describe ("with invalid authentication", function ()

        for _, method in ipairs { "DELETE", "HEAD", "GET", "OPTIONS", "PATCH", "POST", "PUT" } do
          it ("answers to " .. method, function ()
            local token  = Test.make_false_token (Test.identities.rahan)
            local status = request (app, route, {
              method  = method,
              headers = { Authorization = "Bearer " .. token},
            })
            assert.are.same (status, 401)
          end)
        end

      end)

    end)

    describe ("an existing resource", function ()

      describe ("without authentication", function ()

        for _, permission in ipairs { "admin", "write", "read" } do
          describe ("with default " .. permission .. " permission", function ()

            before_each (function ()
              local token  = Test.make_token (Test.identities.rahan)
              local status = request (app, project .. "/permissions/anonymous", {
                method  = "PUT",
                json    = { permission = permission },
                headers = { ["Authorization"] = "Bearer " .. token },
              })
              assert.are.same (status, 202)
            end)

            after_each (function ()
              local token = Test.make_token (project)
              pcall (request, app, route, {
                method  = "DELETE",
                headers = { ["Authorization"] = "Bearer " .. token },
              })
            end)

            for _, method in ipairs { "HEAD", "OPTIONS" } do
              it ("answers to " .. method, function ()
                local status = request (app, route, {
                  method = method,
                })
                assert.are.same (status, 204)
              end)
            end

            for _, method in ipairs { "GET" } do
              it ("answers to " .. method, function ()
                local status = request (app, route, {
                  method = method,
                })
                assert.are.same (status, 302)
              end)
            end

            pending "check that websocket correctly works"

            for _, method in ipairs { "PATCH", "POST", "PUT" } do
              it ("answers to " .. method, function ()
                local status = request (app, route, {
                  method = method,
                })
                assert.are.same (status, 405)
              end)
            end

            for _, method in ipairs { "DELETE" } do
              it ("answers to " .. method, function ()
                local status = request (app, route, {
                  method = method,
                })
                assert.are.same (status, 401)
              end)
            end

          end)
        end

        describe ("with default none permission", function ()

          before_each (function ()
            local token  = Test.make_token (Test.identities.rahan)
            local status = request (app, project .. "/permissions/anonymous", {
              method  = "PUT",
              json    = { permission = "none" },
              headers = { ["Authorization"] = "Bearer " .. token },
            })
            assert.are.same (status, 202)
          end)

          after_each (function ()
            local token = Test.make_token (project)
            pcall (request, app, route, {
              method  = "DELETE",
              headers = { ["Authorization"] = "Bearer " .. token },
            })
          end)

          for _, method in ipairs { "HEAD", "GET", "OPTIONS" } do
            it ("answers to " .. method, function ()
              local status = request (app, route, {
                method = method,
              })
              assert.are.same (status, 403)
            end)
          end

          for _, method in ipairs { "PATCH", "POST", "PUT" } do
            it ("answers to " .. method, function ()
              local status = request (app, route, {
                method = method,
              })
              assert.are.same (status, 405)
            end)
          end

          for _, method in ipairs { "DELETE" } do
            it ("answers to " .. method, function ()
              local status = request (app, route, {
                method = method,
              })
              assert.are.same (status, 401)
            end)
          end

        end)

      end)

      describe ("with permission and authentication", function ()

        for _, permission in ipairs { "admin", "write", "read" } do
          describe ("with " .. permission .. " authentication", function ()

            before_each (function ()
              local token  = Test.make_token (Test.identities.rahan)
              local status = request (app, project .. "/permissions/" .. naouna, {
                method  = "PUT",
                json    = { permission = permission },
                headers = {["Authorization"] = "Bearer " .. token },
              })
              assert.are.same (status, 201)
            end)

            after_each (function ()
              local token = Test.make_token (project)
              pcall (request, app, route, {
                method  = "DELETE",
                headers = { ["Authorization"] = "Bearer " .. token },
              })
            end)

            for _, method in ipairs { "HEAD", "OPTIONS" } do
              it ("answers to " .. method, function ()
                local token  = Test.make_token (Test.identities.naouna)
                local status = request (app, route, {
                  method  = method,
                  headers = { Authorization = "Bearer " .. token},
                })
                assert.are.same (status, 204)
              end)
            end

            for _, method in ipairs { "GET" } do
              it ("answers to " .. method, function ()
                local token = Test.make_token (Test.identities.naouna)
                local status, _, _ = request (app, route, {
                  method  = method,
                  headers = { Authorization = "Bearer " .. token},
                })
                assert.are.same (status, 302)
              end)
            end

            pending "check that websocket correctly works"

            for _, method in ipairs { "PATCH", "POST", "PUT" } do
              it ("answers to " .. method, function ()
                local token  = Test.make_token (Test.identities.naouna)
                local status = request (app, route, {
                  method  = method,
                  headers = { Authorization = "Bearer " .. token},
                })
                assert.are.same (status, 405)
              end)
            end

            for _, method in ipairs { "DELETE" } do
              it ("answers to " .. method, function ()
                local token  = Test.make_token (Test.identities.naouna)
                local status = request (app, route, {
                  method  = method,
                  headers = { Authorization = "Bearer " .. token},
                })
                assert.are.same (status, 403)
              end)
            end

          end)
        end

        describe ("with none authentication", function ()

          before_each (function ()
            local token  = Test.make_token (Test.identities.rahan)
            local status = request (app, project .. "/permissions/" .. naouna, {
              method  = "PUT",
              json    = { permission = "none" },
              headers = { ["Authorization"] = "Bearer " .. token },
            })
            assert.are.same (status, 201)
          end)

          after_each (function ()
            local token = Test.make_token (project)
            pcall (request, app, route, {
              method  = "DELETE",
              headers = { ["Authorization"] = "Bearer " .. token },
            })
          end)

          for _, method in ipairs { "DELETE", "HEAD", "GET", "OPTIONS" } do
            it ("answers to " .. method, function ()
              local token  = Test.make_token (Test.identities.naouna)
              local status = request (app, route, {
                method  = method,
                headers = { Authorization = "Bearer " .. token},
              })
              assert.are.same (status, 403)
            end)
          end

          for _, method in ipairs { "PATCH", "POST", "PUT" } do
            it ("answers to " .. method, function ()
              local token  = Test.make_token (Test.identities.naouna)
              local status = request (app, route, {
                method  = method,
                headers = { Authorization = "Bearer " .. token},
              })
              assert.are.same (status, 405)
            end)
          end

        end)

      end)

      describe ("with valid authentication", function ()

        for _, permission in ipairs { "admin", "write", "read" } do
          describe ("with default " .. permission .. " permission", function ()

            before_each (function ()
              local token  = Test.make_token (Test.identities.rahan)
              local status = request (app, project .. "/permissions/user", {
                method  = "PUT",
                json    = { permission = permission },
                headers = { ["Authorization"] = "Bearer " .. token },
              })
              assert.are.same (status, 202)
            end)

            after_each (function ()
              local token = Test.make_token (project)
              pcall (request, app, route, {
                method  = "DELETE",
                headers = { ["Authorization"] = "Bearer " .. token },
              })
            end)

            for _, method in ipairs { "HEAD", "OPTIONS" } do
              it ("answers to " .. method, function ()
                local token  = Test.make_token (Test.identities.naouna)
                local status = request (app, route, {
                  method  = method,
                  headers = { Authorization = "Bearer " .. token},
                })
                assert.are.same (status, 204)
              end)
            end

            for _, method in ipairs { "GET" } do
              it ("answers to " .. method, function ()
                local token  = Test.make_token (Test.identities.naouna)
                local status = request (app, route, {
                  method  = method,
                  headers = { Authorization = "Bearer " .. token},
                })
                assert.are.same (status, 302)
              end)
            end

            pending "check that websocket correctly works"

            for _, method in ipairs { "PATCH", "POST", "PUT" } do
              it ("answers to " .. method, function ()
                local token  = Test.make_token (Test.identities.naouna)
                local status = request (app, route, {
                  method  = method,
                  headers = { Authorization = "Bearer " .. token},
                })
                assert.are.same (status, 405)
              end)
            end

            for _, method in ipairs { "DELETE" } do
              it ("answers to " .. method, function ()
                local token  = Test.make_token (Test.identities.naouna)
                local status = request (app, route, {
                  method  = method,
                  headers = { Authorization = "Bearer " .. token},
                })
                assert.are.same (status, 403)
              end)
            end

          end)

        end

        describe ("with default none permission", function ()

          before_each (function ()
            local token  = Test.make_token (Test.identities.rahan)
            local status = request (app, project .. "/permissions/user", {
              method  = "PUT",
              json    = { permission = "none" },
              headers = { ["Authorization"] = "Bearer " .. token },
            })
            assert.are.same (status, 202)
          end)

          after_each (function ()
            local token = Test.make_token (project)
            pcall (request, app, route, {
              method  = "DELETE",
              headers = { ["Authorization"] = "Bearer " .. token },
            })
          end)

          for _, method in ipairs { "DELETE", "HEAD", "GET", "OPTIONS" } do
            it ("answers to " .. method, function ()
              local token  = Test.make_token (Test.identities.naouna)
              local status = request (app, route, {
                method  = method,
                headers = { Authorization = "Bearer " .. token},
              })
              assert.are.same (status, 403)
            end)
          end

          for _, method in ipairs { "PATCH", "POST", "PUT" } do
            it ("answers to " .. method, function ()
              local token  = Test.make_token (Test.identities.naouna)
              local status = request (app, route, {
                method  = method,
                headers = { Authorization = "Bearer " .. token},
              })
              assert.are.same (status, 405)
            end)
          end

        end)

      end)

      describe ("with invalid authentication", function ()

        for _, method in ipairs { "DELETE", "HEAD", "GET", "OPTIONS", "PATCH", "POST", "PUT" } do
          it ("answers to " .. method, function ()
            local token  = Test.make_false_token (Test.identities.rahan)
            local status = request (app, route, {
              method  = method,
              headers = { Authorization = "Bearer " .. token},
            })
            assert.are.same (status, 401)
          end)
        end

      end)

      describe ("with project authentication", function ()

        for _, method in ipairs { "HEAD", "OPTIONS" } do
          it ("answers to " .. method, function ()
            local token  = Test.make_token (project)
            local status = request (app, route, {
              method  = method,
              headers = { Authorization = "Bearer " .. token},
            })
            assert.are.same (status, 204)
          end)
        end

        for _, method in ipairs { "GET" } do
          it ("answers to " .. method, function ()
            local token  = Test.make_token (project)
            local status = request (app, route, {
              method  = method,
              headers = { Authorization = "Bearer " .. token},
            })
            assert.are.same (status, 302)
          end)
        end

        pending "check that websocket correctly works"

        for _, method in ipairs { "PATCH", "POST", "PUT" } do
          it ("answers to " .. method, function ()
            local token  = Test.make_token (project)
            local status = request (app, route, {
              method  = method,
              headers = { Authorization = "Bearer " .. token},
            })
            assert.are.same (status, 405)
          end)
        end

        for _, method in ipairs { "DELETE" } do
          it ("answers to " .. method, function ()
            local token  = Test.make_token (project)
            local status = request (app, route, {
              method  = method,
              headers = { Authorization = "Bearer " .. token},
            })
            assert.are.same (status, 204)
          end)
        end

      end)

    end)

  end)

end)
