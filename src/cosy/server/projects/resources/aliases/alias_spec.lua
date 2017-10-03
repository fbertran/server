local Test = require "cosy.server.test"

describe ("route /projects/:project/resources/:resource/aliases/", function ()

  Test.environment.use ()

  local app, project, resource, route, request, naouna

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
    project = result.path
    status, result = request (app, project .. "/resources", {
      method  = "POST",
      headers = {
        Authorization = "Bearer " .. token,
      },
    })
    assert.are.same (status, 201)
    resource = result.path
    route    = resource .. "/aliases/alias"
    status = request (app, resource .. "/aliases/alias", {
      method  = "PUT",
      headers = {
        Authorization = "Bearer " .. token,
      },
    })
    assert.are.same (status, 201)
  end)

  it ("when already existing", function ()
    local token = Test.make_token (Test.identities.rahan)
    local status, result = request (app, project .. "/resources", {
      method  = "POST",
      headers = {
        Authorization = "Bearer " .. token,
      },
    })
    assert.are.same (status, 201)
    resource = result.path
    route    = resource .. "/aliases/alias"
    status = request (app, resource .. "/aliases/alias", {
      method  = "PUT",
      headers = {
        Authorization = "Bearer " .. token,
      },
    })
    assert.are.same (status, 409)
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

        for _, permission in ipairs { "admin", "write" } do
          describe ("with default " .. permission .. " permission", function ()

            before_each (function ()
              local token  = Test.make_token (Test.identities.rahan)
              local status = request (app, project .. "/permissions/anonymous", {
                method  = "PUT",
                json    = { permission = permission },
                headers = { ['Authorization'] = "Bearer " .. token },
              })
              assert.are.same (status, 202)
            end)

            for _, method in ipairs { "HEAD", "GET", "OPTIONS" } do
              it ("answers to " .. method, function ()
                local status, _, headers = request (app, route, {
                  method = method,
                })
                assert.are.same (status, 302)
                assert.is_truthy (headers.location:match (resource))
              end)
            end

            for _, method in ipairs { "DELETE", "PUT" } do
              it ("answers to " .. method, function ()
                local status = request (app, route, {
                  method = method,
                })
                assert.are.same (status, 401)
              end)
            end

            for _, method in ipairs { "PATCH", "POST" } do
              it ("answers to " .. method, function ()
                local status = request (app, route, {
                  method = method,
                })
                assert.are.same (status, 405)
              end)
            end

          end)
        end

        for _, permission in ipairs { "read" } do
          describe ("with default " .. permission .. " permission", function ()

            before_each (function ()
              local token  = Test.make_token (Test.identities.rahan)
              local status = request (app, project .. "/permissions/anonymous", {
                method  = "PUT",
                json    = { permission = permission },
                headers = { ['Authorization'] = "Bearer " .. token },
              })
              assert.are.same (status, 202)
            end)

            for _, method in ipairs { "HEAD", "GET", "OPTIONS" } do
              it ("answers to " .. method, function ()
                local status, _, headers = request (app, route, {
                  method = method,
                })
                assert.are.same (status, 302)
                assert.is_truthy (headers.location:match (resource))
              end)
            end

            for _, method in ipairs { "DELETE", "PUT" } do
              it ("answers to " .. method, function ()
                local status = request (app, route, {
                  method = method,
                })
                assert.are.same (status, 401)
              end)
            end

            for _, method in ipairs { "PATCH", "POST" } do
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
              headers = { ['Authorization'] = "Bearer " .. token },
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

          for _, method in ipairs { "DELETE", "PUT" } do
            it ("answers to " .. method, function ()
              local status = request (app, route, {
                method = method,
              })
              assert.are.same (status, 401)
            end)
          end

          for _, method in ipairs { "PATCH", "POST" } do
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
                headers = { ['Authorization'] = "Bearer " .. token },
              })
              assert.are.same (status, 201)
            end)

            for _, method in ipairs { "HEAD", "GET", "OPTIONS" } do
              it ("answers to " .. method, function ()
                local token = Test.make_token (Test.identities.naouna)
                local status, _, headers = request (app, route, {
                  method  = method,
                  headers = { Authorization = "Bearer " .. token},
                })
                assert.are.same (status, 302)
                assert.is_truthy (headers.location:match (resource))
              end)
            end

            for _, method in ipairs { "PUT" } do
              it ("answers to " .. method, function ()
                local token  = Test.make_token (Test.identities.naouna)
                local status = request (app, route, {
                  method  = method,
                  headers = { Authorization = "Bearer " .. token},
                })
                assert.are.same (status, 202)
              end)

              it ("answers to " .. method, function ()
                local token  = Test.make_token (Test.identities.naouna)
                local status = request (app, route .. "-2", {
                  method  = method,
                  headers = { Authorization = "Bearer " .. token},
                })
                assert.are.same (status, 201)
              end)
            end

            for _, method in ipairs { "DELETE" } do
              it ("answers to " .. method, function ()
                local token  = Test.make_token (Test.identities.naouna)
                local status = request (app, route, {
                  method  = method,
                  headers = { Authorization = "Bearer " .. token},
                })
                assert.are.same (status, 204)
              end)

              it ("answers to " .. method, function ()
                local token  = Test.make_token (Test.identities.naouna)
                local status = request (app, route, {
                  method  = method,
                  headers = { Authorization = "Bearer " .. token},
                })
                assert.are.same (status, 204)
                status = request (app, route, {
                  method  = method,
                  headers = { Authorization = "Bearer " .. token},
                })
                assert.are.same (status, 404)
              end)
            end

            for _, method in ipairs { "PATCH", "POST" } do
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

        for _, permission in ipairs { "read" } do
          describe ("with " .. permission .. " authentication", function ()

            before_each (function ()
              local token  = Test.make_token (Test.identities.rahan)
              local status = request (app, project .. "/permissions/" .. naouna, {
                method  = "PUT",
                json    = { permission = permission },
                headers = { ['Authorization'] = "Bearer " .. token },
              })
              assert.are.same (status, 201)
            end)

            for _, method in ipairs { "HEAD", "GET", "OPTIONS" } do
              it ("answers to " .. method, function ()
                local token = Test.make_token (Test.identities.naouna)
                local status, _, headers = request (app, route, {
                  method  = method,
                  headers = { Authorization = "Bearer " .. token},
                })
                assert.are.same (status, 302)
                assert.is_truthy (headers.location:match (resource))
              end)
            end

            for _, method in ipairs { "DELETE", "PUT" } do
              it ("answers to " .. method, function ()
                local token  = Test.make_token (Test.identities.naouna)
                local status = request (app, route, {
                  method  = method,
                  headers = { Authorization = "Bearer " .. token},
                })
                assert.are.same (status, 403)
              end)
            end

            for _, method in ipairs { "PATCH", "POST" } do
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

        describe ("with none authentication", function ()

          before_each (function ()
            local token  = Test.make_token (Test.identities.rahan)
            local status = request (app, project .. "/permissions/" .. naouna, {
              method  = "PUT",
              json    = { permission = "none" },
              headers = { ['Authorization'] = "Bearer " .. token },
            })
            assert.are.same (status, 201)
          end)

          for _, method in ipairs { "DELETE", "HEAD", "GET", "OPTIONS", "PUT" } do
            it ("answers to " .. method, function ()
              local token  = Test.make_token (Test.identities.naouna)
              local status = request (app, route, {
                method  = method,
                headers = { Authorization = "Bearer " .. token},
              })
              assert.are.same (status, 403)
            end)
          end

          for _, method in ipairs { "PATCH", "POST" } do
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

        for _, permission in ipairs { "admin", "write" } do
          describe ("with default " .. permission .. " permission", function ()

            before_each (function ()
              local token  = Test.make_token (Test.identities.rahan)
              local status = request (app, project .. "/permissions/user", {
                method  = "PUT",
                json    = { permission = permission },
                headers = { ['Authorization'] = "Bearer " .. token },
              })
              assert.are.same (status, 202)
            end)

            for _, method in ipairs { "HEAD", "GET", "OPTIONS" } do
              it ("answers to " .. method, function ()
                local token = Test.make_token (Test.identities.naouna)
                local status, _, headers = request (app, route, {
                  method  = method,
                  headers = { Authorization = "Bearer " .. token},
                })
                assert.are.same (status, 302)
                assert.is_truthy (headers.location:match (resource))
              end)
            end

            for _, method in ipairs { "PUT" } do
              it ("answers to " .. method, function ()
                local token  = Test.make_token (Test.identities.naouna)
                local status = request (app, route, {
                  method  = method,
                  headers = { Authorization = "Bearer " .. token},
                })
                assert.are.same (status, 202)
              end)

              it ("answers to " .. method, function ()
                local token  = Test.make_token (Test.identities.naouna)
                local status = request (app, route .. "-2", {
                  method  = method,
                  headers = { Authorization = "Bearer " .. token},
                })
                assert.are.same (status, 201)
              end)
            end

            for _, method in ipairs { "DELETE" } do
              it ("answers to " .. method, function ()
                local token  = Test.make_token (Test.identities.naouna)
                local status = request (app, route, {
                  method  = method,
                  headers = { Authorization = "Bearer " .. token},
                })
                assert.are.same (status, 204)
              end)

              it ("answers to " .. method, function ()
                local token  = Test.make_token (Test.identities.naouna)
                local status = request (app, route, {
                  method  = method,
                  headers = { Authorization = "Bearer " .. token},
                })
                assert.are.same (status, 204)
                status = request (app, route, {
                  method  = method,
                  headers = { Authorization = "Bearer " .. token},
                })
                assert.are.same (status, 404)
              end)
            end

            for _, method in ipairs { "PATCH", "POST" } do
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

        for _, permission in ipairs { "read" } do
          describe ("with default " .. permission .. " permission", function ()

            before_each (function ()
              local token  = Test.make_token (Test.identities.rahan)
              local status = request (app, project .. "/permissions/user", {
                method  = "PUT",
                json    = { permission = permission },
                headers = { ['Authorization'] = "Bearer " .. token },
              })
              assert.are.same (status, 202)
            end)

            for _, method in ipairs { "HEAD", "GET", "OPTIONS" } do
              it ("answers to " .. method, function ()
                local token = Test.make_token (Test.identities.naouna)
                local status, _, headers = request (app, route, {
                  method  = method,
                  headers = { Authorization = "Bearer " .. token},
                })
                assert.are.same (status, 302)
                assert.is_truthy (headers.location:match (resource))
              end)
            end

            for _, method in ipairs { "DELETE", "PUT" } do
              it ("answers to " .. method, function ()
                local token  = Test.make_token (Test.identities.naouna)
                local status = request (app, route, {
                  method  = method,
                  headers = { Authorization = "Bearer " .. token},
                })
                assert.are.same (status, 403)
              end)
            end

            for _, method in ipairs { "PATCH", "POST" } do
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

        describe ("with default none permission", function ()

          before_each (function ()
            local token  = Test.make_token (Test.identities.rahan)
            local status = request (app, project .. "/permissions/user", {
              method  = "PUT",
              json    = { permission = "none" },
              headers = { ['Authorization'] = "Bearer " .. token },
            })
            assert.are.same (status, 202)
          end)

          for _, method in ipairs { "DELETE", "HEAD", "GET", "OPTIONS", "PUT" } do
            it ("answers to " .. method, function ()
              local token  = Test.make_token (Test.identities.naouna)
              local status = request (app, route, {
                method  = method,
                headers = { Authorization = "Bearer " .. token},
              })
              assert.are.same (status, 403)
            end)
          end

          for _, method in ipairs { "PATCH", "POST" } do
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

    end)

  end)

end)
