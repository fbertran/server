local assert = require "luassert"
local Test   = require "cosy.server.test"

Test.environment.use ()

describe ("#resty route /projects/:project/resources/:resource/executions/", function ()

  local app, request

  setup (function ()
    Test.clean_db ()
    request = Test.environment.request ()
    app     = Test.environment.app ()
  end)

  teardown (function ()
    while true do
      local status, info = request (app, "/", {
        method = "GET",
      })
      assert.are.equal (status, 200)
      if info.stats.services == 0 then
        break
      end
      os.execute [[ sleep 1 ]]
    end
  end)

  local project_token, project, route, naouna

  setup (function ()
    local token = Test.make_token (Test.identities.naouna)
    local status, result = request (app, "/", {
      method  = "GET",
      headers = { Authorization = "Bearer " .. token },
    })
    assert.are.same (status, 200)
    naouna = result.authentified.path:match "/users/(.*)"
  end)

  local execution

  after_each (function ()
    if execution then
      request (app, execution, {
        method  = "DELETE",
        headers = { ["Authorization"] = "Bearer " .. project_token },
      })
    end
  end)

  describe ("accessed as", function ()

    describe ("a non-existing resource", function ()

      before_each (function ()
        local token = Test.make_token (Test.identities.rahan)
        local status, result = request (app, "/projects/", {
          method  = "POST",
          headers = {
            Authorization = "Bearer " .. token,
          },
        })
        assert.are.same (status, 201)
        project_token = Test.make_token (result.path)
        local project_url = result.path
        status = request (app, project_url .. "/permissions/user", {
          method  = "PUT",
          json    = { permission = "read" },
          headers = { ["Authorization"] = "Bearer " .. token },
        })
        assert.are.same (status, 202)
        status = request (app, project_url .. "/permissions/anonymous", {
          method  = "PUT",
          json    = { permission = "read" },
          headers = { ["Authorization"] = "Bearer " .. token },
        })
        assert.are.same (status, 202)
        status, result = request (app, project_url .. "/resources/", {
          method  = "POST",
          headers = {
            Authorization = "Bearer " .. token,
          },
        })
        assert.are.same (status, 201)
        route = result.path .. "/executions"
        status = request (app, result.path, {
          method  = "DELETE",
          headers = {
            Authorization = "Bearer " .. token,
          },
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

      before_each (function ()
        local token = Test.make_token (Test.identities.rahan)
        local status, result = request (app, "/projects", {
          method  = "POST",
          headers = {
            Authorization = "Bearer " .. token,
          },
        })
        assert.are.same (status, 201)
        project_token = Test.make_token (result.path)
        project = result.path
        status = request (app, project .. "/permissions/user", {
          method  = "PUT",
          json    = { permission = "read" },
          headers = { ["Authorization"] = "Bearer " .. token },
        })
        assert.are.same (status, 202)
        status = request (app, project .. "/permissions/anonymous", {
          method  = "PUT",
          json    = { permission = "read" },
          headers = { ["Authorization"] = "Bearer " .. token },
        })
        assert.are.same (status, 202)
        status, result = request (app, project .. "/resources/", {
          method  = "POST",
          headers = {
            Authorization = "Bearer " .. token,
          },
        })
        assert.are.same (status, 201)
        route = result.path .. "/executions"
      end)

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
                assert.are.same (status, 200)
              end)
            end

            for _, method in ipairs { "POST" } do
              it ("answers to " .. method, function ()
                local status = request (app, route, {
                  method = method,
                  json   = {
                    image = "sylvainlasnier/echo",
                  },
                })
                assert.are.same (status, 401)
              end)
            end

            for _, method in ipairs { "DELETE", "PATCH", "PUT" } do
              it ("answers to " .. method, function ()
                local status = request (app, route, {
                  method = method,
                })
                assert.are.same (status, 405)
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

          for _, method in ipairs { "HEAD", "GET", "OPTIONS" } do
            it ("answers to " .. method, function ()
              local status = request (app, route, {
                method = method,
              })
              assert.are.same (status, 403)
            end)
          end

          for _, method in ipairs { "POST" } do
            it ("answers to " .. method, function ()
              local status = request (app, route, {
                method = method,
                json   = {
                  image = "sylvainlasnier/echo",
                },
              })
              assert.are.same (status, 401)
            end)
          end

          for _, method in ipairs { "DELETE", "PATCH", "PUT" } do
            it ("answers to " .. method, function ()
              local status = request (app, route, {
                method = method,
              })
              assert.are.same (status, 405)
            end)
          end

        end)

      end)

      describe ("with permission and authentication", function ()

        for _, permission in ipairs { "admin", "write" } do
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
                assert.are.same (status, 200)
              end)
            end

            for _, method in ipairs { "POST" } do
              it ("answers to " .. method, function ()
                local token = Test.make_token (Test.identities.naouna)
                local status, result = request (app, route, {
                  method  = method,
                  headers = { Authorization = "Bearer " .. token},
                  json    = {
                    image = "sylvainlasnier/echo",
                  },
                })
                assert.are.same (status, 202)
                execution = result.path
              end)
            end

            for _, method in ipairs { "DELETE", "PATCH", "PUT" } do
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
        end

        for _, permission in ipairs { "read", "none" } do
          describe ("with " .. permission .. " authentication", function ()

            before_each (function ()
              local token  = Test.make_token (Test.identities.rahan)
              local status = request (app, project .. "/permissions/" .. naouna, {
                method  = "PUT",
                json    = { permission = "none" },
                headers = { ["Authorization"] = "Bearer " .. token },
              })
              assert.are.same (status, 201)
            end)

            for _, method in ipairs { "HEAD", "GET", "OPTIONS", "POST" } do
              it ("answers to " .. method, function ()
                local token  = Test.make_token (Test.identities.naouna)
                local status = request (app, route, {
                  method  = method,
                  headers = { Authorization = "Bearer " .. token},
                })
                assert.are.same (status, 403)
              end)
            end

            for _, method in ipairs { "DELETE", "PATCH", "PUT" } do
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
        end

      end)

      describe ("with valid authentication", function ()

        for _, permission in ipairs { "admin", "write" } do
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
                assert.are.same (status, 200)
              end)
            end

            for _, method in ipairs { "POST" } do
              it ("answers to " .. method, function ()
                local token = Test.make_token (Test.identities.rahan)
                local status, result = request (app, route, {
                  method  = method,
                  headers = { Authorization = "Bearer " .. token},
                  json    = {
                    image = "sylvainlasnier/echo",
                  },
                })
                assert.are.same (status, 202)
                execution = result.path
              end)
            end

            for _, method in ipairs { "DELETE", "PATCH", "PUT" } do
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

        end

        for _, permission in ipairs { "read", "none" } do
          describe ("with default " .. permission .. " permission", function ()

            before_each (function ()
              local token  = Test.make_token (Test.identities.rahan)
              local status = request (app, project .. "/permissions/user", {
                method  = "PUT",
                json    = { permission = "none" },
                headers = { ["Authorization"] = "Bearer " .. token },
              })
              assert.are.same (status, 202)
            end)

            for _, method in ipairs { "HEAD", "GET", "OPTIONS", "POST" } do
              it ("answers to " .. method, function ()
                local token  = Test.make_token (Test.identities.naouna)
                local status = request (app, route, {
                  method  = method,
                  headers = { Authorization = "Bearer " .. token},
                })
                assert.are.same (status, 403)
              end)
            end

            for _, method in ipairs { "DELETE", "PATCH", "PUT" } do
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

      describe ("with project authentication", function ()

        for _, method in ipairs { "HEAD", "OPTIONS" } do
          it ("answers to " .. method, function ()
            local status = request (app, route, {
              method  = method,
              headers = { Authorization = "Bearer " .. project_token},
            })
            assert.are.same (status, 204)
          end)
        end

        for _, method in ipairs { "GET" } do
          it ("answers to " .. method, function ()
            local status = request (app, route, {
              method  = method,
              headers = { Authorization = "Bearer " .. project_token},
            })
            assert.are.same (status, 200)
          end)
        end

        for _, method in ipairs { "POST" } do
          it ("answers to " .. method, function ()
            local status, result = request (app, route, {
              method  = method,
              headers = { Authorization = "Bearer " .. project_token},
              json    = {
                image = "sylvainlasnier/echo",
              },
            })
            assert.are.same (status, 202)
            execution = result.path
          end)
        end

        for _, method in ipairs { "DELETE", "PATCH", "PUT" } do
          it ("answers to " .. method, function ()
            local status = request (app, route, {
              method  = method,
              headers = { Authorization = "Bearer " .. project_token},
            })
            assert.are.same (status, 405)
          end)
        end

      end)

      describe ("with non existing image", function ()

        for _, method in ipairs { "POST" } do
          it ("answers to " .. method, function ()
            local token  = Test.make_token (Test.identities.rahan)
            local status = request (app, route, {
              method  = method,
              headers = { Authorization = "Bearer " .. token},
              json    = {
                image = "cosyverif/nothing",
              },
            })
            assert.are.same (status, 400)
          end)
        end

      end)

    end)

  end)

end)
