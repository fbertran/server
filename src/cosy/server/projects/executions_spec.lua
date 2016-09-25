local assert   = require "luassert"
local Test     = require "cosy.server.test"
local Http     = require "cosy.server.http"
local Instance = require "cosy.server.instance"

Test.environment.use ()

describe ("#resty route /projects/:project/executions/", function ()

  local app, request
  local instance, server_url

  setup (function ()
    instance   = Instance.create ()
    server_url = instance.server
  end)

  teardown (function ()
    instance:delete ()
  end)

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

  local project, project_token, resources, route, naouna

  setup (function ()
    local token = Test.make_token (Test.identities.rahan)
    resources   = {}
    do -- existing resource
      local result, status = Http.json {
        url     = server_url .. "/projects/",
        method  = "POST",
        headers = {
          Authorization = "Bearer " .. token,
        },
      }
      assert.are.same (status, 201)
      local project_url = server_url .. result.path
      local _
      _, status = Http.json {
        url     = project_url .. "/permissions/user",
        method  = "PUT",
        body    = { permission = "read" },
        headers = { ["Authorization"] = "Bearer " .. token },
      }
      assert.are.same (status, 202)
      _, status = Http.json {
        url     = project_url .. "/permissions/anonymous",
        method  = "PUT",
        body    = { permission = "read" },
        headers = { ["Authorization"] = "Bearer " .. token },
      }
      assert.are.same (status, 202)
      result, status = Http.json {
        url     = project_url .. "/resources/",
        method  = "POST",
        headers = {
          Authorization = "Bearer " .. token,
        },
      }
      assert.are.same (status, 201)
      resources.readable = server_url .. result.path
    end
    do -- missing resource
      local result, status = Http.json {
        url     = server_url .. "/projects/",
        method  = "POST",
        headers = {
          Authorization = "Bearer " .. token,
        },
      }
      assert.are.same (status, 201)
      local project_url = server_url .. result.path
      local _
      _, status = Http.json {
        url     = project_url .. "/permissions/user",
        method  = "PUT",
        body    = { permission = "read" },
        headers = { ["Authorization"] = "Bearer " .. token },
      }
      assert.are.same (status, 202)
      _, status = Http.json {
        url     = project_url .. "/permissions/anonymous",
        method  = "PUT",
        body    = { permission = "read" },
        headers = { ["Authorization"] = "Bearer " .. token },
      }
      assert.are.same (status, 202)
      result, status = Http.json {
        url     = project_url .. "/resources/",
        method  = "POST",
        headers = {
          Authorization = "Bearer " .. token,
        },
      }
      assert.are.same (status, 201)
      resources.missing = server_url .. result.path
      _, status = Http.json {
        url     = resources.missing,
        method  = "DELETE",
        headers = {
          Authorization = "Bearer " .. token,
        },
      }
      assert.are.same (status, 204)
    end
    do -- non-readable resource
      local result, status = Http.json {
        url     = server_url .. "/projects/",
        method  = "POST",
        headers = {
          Authorization = "Bearer " .. token,
        },
      }
      assert.are.same (status, 201)
      local project_url = server_url .. result.path
      local _
      _, status = Http.json {
        url     = project_url .. "/permissions/user",
        method  = "PUT",
        body    = { permission = "none" },
        headers = { ["Authorization"] = "Bearer " .. token },
      }
      assert.are.same (status, 202)
      _, status = Http.json {
        url     = project_url .. "/permissions/anonymous",
        method  = "PUT",
        body    = { permission = "none" },
        headers = { ["Authorization"] = "Bearer " .. token },
      }
      assert.are.same (status, 202)
      result, status = Http.json {
        url     = project_url .. "/resources/",
        method  = "POST",
        headers = {
          Authorization = "Bearer " .. token,
        },
      }
      assert.are.same (status, 201)
      resources.hidden = server_url .. result.path
    end
  end)

  before_each (function ()
    local token = Test.make_token (Test.identities.naouna)
    local status, result = request (app, "/", {
      method  = "GET",
      headers = { Authorization = "Bearer " .. token },
    })
    assert.are.same (status, 200)
    naouna = result.authentified.path:match "/users/(.*)"
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
    project       = result.path
    route         = project .. "/executions/"
    project_token = Test.make_token (result.path)
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
                    image    = "sylvainlasnier/echo",
                    resource = resources.readable,
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
                  image    = "sylvainlasnier/echo",
                  resource = resources.readable,
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
                    image    = "sylvainlasnier/echo",
                    resource = resources.readable,
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
                    image    = "sylvainlasnier/echo",
                    resource = resources.readable,
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
            local status = request (app, route, {
              method  = method,
              headers = { Authorization = "Bearer " .. project_token},
              json    = {
                image    = "sylvainlasnier/echo",
                resource = resources.readable,
              },
            })
            assert.are.same (status, 401)
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
                image    = "cosyverif/nothing",
                resource = resources.readable,
              },
            })
            assert.are.same (status, 400)
          end)
        end

      end)

      describe ("with non existing resource", function ()

        for _, method in ipairs { "POST" } do
          it ("answers to " .. method, function ()
            local token  = Test.make_token (Test.identities.rahan)
            local status = request (app, route, {
              method  = method,
              headers = { Authorization = "Bearer " .. token},
              json    = {
                image    = "sylvainlasnier/echo",
                resource = resources.missing,
              },
            })
            assert.are.same (status, 400)
          end)
        end

      end)

      describe ("with non readable resource", function ()

        before_each (function ()
          local token  = Test.make_token (Test.identities.rahan)
          local status = request (app, project .. "/permissions/" .. naouna, {
            method  = "PUT",
            json    = { permission = "admin" },
            headers = {["Authorization"] = "Bearer " .. token },
          })
          assert.are.same (status, 201)
        end)

        for _, method in ipairs { "POST" } do
          it ("answers to " .. method, function ()
            local token  = Test.make_token (Test.identities.naouna)
            local status = request (app, route, {
              method  = method,
              headers = { Authorization = "Bearer " .. token},
              json    = {
                image    = "sylvainlasnier/echo",
                resource = resources.hidden,
              },
            })
            assert.are.same (status, 400)
          end)
        end

      end)

    end)

  end)

end)
