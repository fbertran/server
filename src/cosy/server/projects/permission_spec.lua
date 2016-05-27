local Test = require "cosy.server.test"


describe ("route /projects/:project/permissions/anonymous", function ()

  Test.environment.use ()

  local Util, app, project, route, request, naouna

  before_each (function ()
    Util    = require "lapis.util"
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
    result = Util.from_json (result)
    assert.is.not_nil (result.user.id)
    naouna = result.user.id
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
    result = Util.from_json (result)
    assert.is.not_nil (result.id)
    project = "/projects/" .. result.id
    route   = "/projects/" .. result.id .. "/permissions/anonymous"
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

        describe ("with default admin permission", function ()

          before_each (function ()
            local token  = Test.make_token (Test.identities.rahan)
            local status = request (app, project .. "/permissions/anonymous", {
              method  = "PUT",
              post    = Util.to_json { permission = "admin" },
              headers = {
                ["Authorization"] = "Bearer " .. token,
                ["Content-type" ] = "application/json",
              },
            })
            assert.are.same (status, 202)
          end)

          for _, method in ipairs { "HEAD", "GET", "OPTIONS", "PUT" } do
            it ("answers to " .. method, function ()
              local status = request (app, route, {
                method = method,
              })
              assert.are.same (status, 401)
            end)
          end

          for _, method in ipairs { "DELETE", "PATCH", "POST" } do
            it ("answers to " .. method, function ()
              local status = request (app, route, {
                method = method,
              })
              assert.are.same (status, 405)
            end)
          end

        end)

        for _, permission in ipairs { "write", "read", "none" } do
          describe ("with default " .. permission .. " permission", function ()

            before_each (function ()
              local token  = Test.make_token (Test.identities.rahan)
              local status = request (app, project .. "/permissions/anonymous", {
                method  = "PUT",
                post    = Util.to_json { permission = permission },
                headers = {
                  ["Authorization"] = "Bearer " .. token,
                  ["Content-type" ] = "application/json",
                },
              })
              assert.are.same (status, 202)
            end)

            for _, method in ipairs { "HEAD", "GET", "OPTIONS", "PUT" } do
              it ("answers to " .. method, function ()
                local status = request (app, route, {
                  method = method,
                })
                assert.are.same (status, 401)
              end)
            end

            for _, method in ipairs { "DELETE", "PATCH", "POST" } do
              it ("answers to " .. method, function ()
                local status = request (app, route, {
                  method = method,
                })
                assert.are.same (status, 405)
              end)
            end

          end)
        end

      end)

      describe ("with permission and authentication", function ()

        describe ("with admin authentication", function ()

          before_each (function ()
            local token  = Test.make_token (Test.identities.rahan)
            local status = request (app, project .. "/permissions/" .. naouna, {
              method  = "PUT",
              post    = Util.to_json { permission = "admin" },
              headers = {
                ["Authorization"] = "Bearer " .. token,
                ["Content-type" ] = "application/json",
              },
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

          for _, method in ipairs { "PUT" } do
            it ("answers to " .. method, function ()
              local token  = Test.make_token (Test.identities.naouna)
              local status = request (app, route, {
                method  = method,
                post    = Util.to_json { permission = "admin" },
                headers = {
                  ['Authorization'] = "Bearer " .. token,
                  ["Content-type" ] = "application/json",
                },
              })
              assert.are.same (status, 202)
              status = request (app, route, {
                method  = method,
                post    = Util.to_json { permission = "something false" },
                headers = {
                  ['Authorization'] = "Bearer " .. token,
                  ["Content-type" ] = "application/json",
                },
              })
              assert.are.same (status, 400)
            end)
          end

          for _, method in ipairs { "DELETE", "PATCH", "POST" } do
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

        for _, permission in ipairs { "write", "read", "none" } do
          describe ("with " .. permission .. " authentication", function ()

            before_each (function ()
              local token  = Test.make_token (Test.identities.rahan)
              local status = request (app, project .. "/permissions/" .. naouna, {
                method  = "PUT",
                post    = Util.to_json { permission = permission },
                headers = {
                  ["Authorization"] = "Bearer " .. token,
                  ["Content-type" ] = "application/json",
                },
              })
              assert.are.same (status, 201)
            end)

            for _, method in ipairs { "HEAD", "GET", "OPTIONS" } do
              it ("answers to " .. method, function ()
                local token  = Test.make_token (Test.identities.naouna)
                local status = request (app, route, {
                  method  = method,
                  headers = { Authorization = "Bearer " .. token},
                })
                assert.are.same (status, 403)
              end)
            end

            for _, method in ipairs { "DELETE", "PATCH", "POST" } do
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

        describe ("with default admin permission", function ()

          before_each (function ()
            local token  = Test.make_token (Test.identities.rahan)
            local status = request (app, project .. "/permissions/user", {
              method  = "PUT",
              post    = Util.to_json { permission = "admin" },
              headers = {
                ["Authorization"] = "Bearer " .. token,
                ["Content-type" ] = "application/json",
              },
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

          for _, method in ipairs { "PUT" } do
            it ("answers to " .. method, function ()
              local token  = Test.make_token (Test.identities.naouna)
              local status = request (app, route, {
                method  = method,
                post    = Util.to_json { permission = "admin" },
                headers = {
                  ['Authorization'] = "Bearer " .. token,
                  ["Content-type" ] = "application/json",
                },
              })
              assert.are.same (status, 202)
              status = request (app, route, {
                method  = method,
                post    = Util.to_json { permission = "something false" },
                headers = {
                  ['Authorization'] = "Bearer " .. token,
                  ["Content-type" ] = "application/json",
                },
              })
              assert.are.same (status, 400)
            end)
          end

          for _, method in ipairs { "DELETE", "PATCH", "POST" } do
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

        for _, permission in ipairs { "write", "read", "none" } do
          describe ("with default " .. permission .. " permission", function ()

            before_each (function ()
              local token  = Test.make_token (Test.identities.rahan)
              local status = request (app, project .. "/permissions/user", {
                method  = "PUT",
                post    = Util.to_json { permission = permission },
                headers = {
                  ["Authorization"] = "Bearer " .. token,
                  ["Content-type" ] = "application/json",
                },
              })
              assert.are.same (status, 202)
            end)

            for _, method in ipairs { "HEAD", "GET", "OPTIONS" } do
              it ("answers to " .. method, function ()
                local token  = Test.make_token (Test.identities.naouna)
                local status = request (app, route, {
                  method  = method,
                  headers = { Authorization = "Bearer " .. token},
                })
                assert.are.same (status, 403)
              end)
            end

            for _, method in ipairs { "DELETE", "PATCH", "POST" } do
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

    end)

  end)

end)


describe ("route /projects/:project/permissions/user", function ()

  Test.environment.use ()

  local Util, app, project, route, request, naouna

  before_each (function ()
    Util    = require "lapis.util"
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
    result = Util.from_json (result)
    assert.is.not_nil (result.user.id)
    naouna = result.user.id
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
    result = Util.from_json (result)
    assert.is.not_nil (result.id)
    project = "/projects/" .. result.id
    route   = "/projects/" .. result.id .. "/permissions/user"
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

        describe ("with default admin permission", function ()

          before_each (function ()
            local token  = Test.make_token (Test.identities.rahan)
            local status = request (app, project .. "/permissions/anonymous", {
              method  = "PUT",
              post    = Util.to_json { permission = "admin" },
              headers = {
                ["Authorization"] = "Bearer " .. token,
                ["Content-type" ] = "application/json",
              },
            })
            assert.are.same (status, 202)
          end)

          for _, method in ipairs { "HEAD", "GET", "OPTIONS", "PUT" } do
            it ("answers to " .. method, function ()
              local status = request (app, route, {
                method = method,
              })
              assert.are.same (status, 401)
            end)
          end

          for _, method in ipairs { "DELETE", "PATCH", "POST" } do
            it ("answers to " .. method, function ()
              local status = request (app, route, {
                method = method,
              })
              assert.are.same (status, 405)
            end)
          end

        end)

        for _, permission in ipairs { "write", "read", "none" } do
          describe ("with default " .. permission .. " permission", function ()

            before_each (function ()
              local token  = Test.make_token (Test.identities.rahan)
              local status = request (app, project .. "/permissions/anonymous", {
                method  = "PUT",
                post    = Util.to_json { permission = permission },
                headers = {
                  ["Authorization"] = "Bearer " .. token,
                  ["Content-type" ] = "application/json",
                },
              })
              assert.are.same (status, 202)
            end)

            for _, method in ipairs { "HEAD", "GET", "OPTIONS", "PUT" } do
              it ("answers to " .. method, function ()
                local status = request (app, route, {
                  method = method,
                })
                assert.are.same (status, 401)
              end)
            end

            for _, method in ipairs { "DELETE", "PATCH", "POST" } do
              it ("answers to " .. method, function ()
                local status = request (app, route, {
                  method = method,
                })
                assert.are.same (status, 405)
              end)
            end

          end)
        end

      end)

      describe ("with permission and authentication", function ()

        describe ("with admin authentication", function ()

          before_each (function ()
            local token  = Test.make_token (Test.identities.rahan)
            local status = request (app, project .. "/permissions/" .. naouna, {
              method  = "PUT",
              post    = Util.to_json { permission = "admin" },
              headers = {
                ["Authorization"] = "Bearer " .. token,
                ["Content-type" ] = "application/json",
              },
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

          for _, method in ipairs { "PUT" } do
            it ("answers to " .. method, function ()
              local token  = Test.make_token (Test.identities.naouna)
              local status = request (app, route, {
                method  = method,
                post    = Util.to_json { permission = "admin" },
                headers = {
                  ['Authorization'] = "Bearer " .. token,
                  ["Content-type" ] = "application/json",
                },
              })
              assert.are.same (status, 202)
              status = request (app, route, {
                method  = method,
                post    = Util.to_json { permission = "something false" },
                headers = {
                  ['Authorization'] = "Bearer " .. token,
                  ["Content-type" ] = "application/json",
                },
              })
              assert.are.same (status, 400)
            end)
          end

          for _, method in ipairs { "DELETE", "PATCH", "POST" } do
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

        for _, permission in ipairs { "write", "read", "none" } do
          describe ("with " .. permission .. " authentication", function ()

            before_each (function ()
              local token  = Test.make_token (Test.identities.rahan)
              local status = request (app, project .. "/permissions/" .. naouna, {
                method  = "PUT",
                post    = Util.to_json { permission = "write" },
                headers = {
                  ["Authorization"] = "Bearer " .. token,
                  ["Content-type" ] = "application/json",
                },
              })
              assert.are.same (status, 201)
            end)

            for _, method in ipairs { "HEAD", "GET", "OPTIONS" } do
              it ("answers to " .. method, function ()
                local token  = Test.make_token (Test.identities.naouna)
                local status = request (app, route, {
                  method  = method,
                  headers = { Authorization = "Bearer " .. token},
                })
                assert.are.same (status, 403)
              end)
            end

            for _, method in ipairs { "DELETE", "PATCH", "POST" } do
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

        describe ("with default admin permission", function ()

          before_each (function ()
            local token  = Test.make_token (Test.identities.rahan)
            local status = request (app, project .. "/permissions/user", {
              method  = "PUT",
              post    = Util.to_json { permission = "admin" },
              headers = {
                ["Authorization"] = "Bearer " .. token,
                ["Content-type" ] = "application/json",
              },
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

          for _, method in ipairs { "PUT" } do
            it ("answers to " .. method, function ()
              local token  = Test.make_token (Test.identities.naouna)
              local status = request (app, route, {
                method  = method,
                post    = Util.to_json { permission = "admin" },
                headers = {
                  ['Authorization'] = "Bearer " .. token,
                  ["Content-type" ] = "application/json",
                },
              })
              assert.are.same (status, 202)
              status = request (app, route, {
                method  = method,
                post    = Util.to_json { permission = "something false" },
                headers = {
                  ['Authorization'] = "Bearer " .. token,
                  ["Content-type" ] = "application/json",
                },
              })
              assert.are.same (status, 400)
            end)
          end

          for _, method in ipairs { "DELETE", "PATCH", "POST" } do
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

        for _, permission in ipairs { "write", "read", "none" } do
          describe ("with default " .. permission .. " permission", function ()

            before_each (function ()
              local token  = Test.make_token (Test.identities.rahan)
              local status = request (app, project .. "/permissions/user", {
                method  = "PUT",
                post    = Util.to_json { permission = permission },
                headers = {
                  ["Authorization"] = "Bearer " .. token,
                  ["Content-type" ] = "application/json",
                },
              })
              assert.are.same (status, 202)
            end)

            for _, method in ipairs { "HEAD", "GET", "OPTIONS" } do
              it ("answers to " .. method, function ()
                local token  = Test.make_token (Test.identities.naouna)
                local status = request (app, route, {
                  method  = method,
                  headers = { Authorization = "Bearer " .. token},
                })
                assert.are.same (status, 403)
              end)
            end

            for _, method in ipairs { "DELETE", "PATCH", "POST" } do
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

    end)

  end)

end)

describe ("route /projects/:project/permissions/:permission", function ()

  Test.environment.use ()

  local Util, app, project, route, request, crao, rahan, naouna

  before_each (function ()
    Util    = require "lapis.util"
    Test.clean_db ()
    request = Test.environment.request ()
    app     = Test.environment.app ()
  end)

  before_each (function ()
    local token = Test.make_token (Test.identities.crao)
    local status, result = request (app, "/", {
      method  = "GET",
      headers = { Authorization = "Bearer " .. token },
    })
    assert.are.same (status, 200)
    result = Util.from_json (result)
    assert.is.not_nil (result.user.id)
    crao = result.user.id
  end)

  before_each (function ()
    local token = Test.make_token (Test.identities.rahan)
    local status, result = request (app, "/", {
      method  = "GET",
      headers = { Authorization = "Bearer " .. token },
    })
    assert.are.same (status, 200)
    result = Util.from_json (result)
    assert.is.not_nil (result.user.id)
    rahan = result.user.id
  end)

  before_each (function ()
    local token = Test.make_token (Test.identities.naouna)
    local status, result = request (app, "/", {
      method  = "GET",
      headers = { Authorization = "Bearer " .. token },
    })
    assert.are.same (status, 200)
    result = Util.from_json (result)
    assert.is.not_nil (result.user.id)
    naouna = result.user.id
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
    result = Util.from_json (result)
    assert.is.not_nil (result.id)
    project = "/projects/" .. result.id
    route   = "/projects/" .. result.id .. "/permissions/" .. crao
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
            local status = request (app, route, {
              method = method,
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

        describe ("with default admin permission", function ()

          before_each (function ()
            local token  = Test.make_token (Test.identities.rahan)
            local status = request (app, project .. "/permissions/anonymous", {
              method  = "PUT",
              post    = Util.to_json { permission = "admin" },
              headers = {
                ["Authorization"] = "Bearer " .. token,
                ["Content-type" ] = "application/json",
              },
            })
            assert.are.same (status, 202)
          end)

          for _, method in ipairs { "DELETE", "HEAD", "GET", "OPTIONS", "PUT" } do
            it ("answers to " .. method, function ()
              local status = request (app, route, {
                method = method,
              })
              assert.are.same (status, 401)
            end)
          end

          for _, method in ipairs { "PATCH", "POST"} do
            it ("answers to " .. method, function ()
              local status = request (app, route, {
                method = method,
              })
              assert.are.same (status, 405)
            end)
          end

        end)

        for _, permission in ipairs { "write", "read", "none" } do
          describe ("with default " .. permission .. " permission", function ()

            before_each (function ()
              local token  = Test.make_token (Test.identities.rahan)
              local status = request (app, project .. "/permissions/anonymous", {
                method  = "PUT",
                post    = Util.to_json { permission = permission },
                headers = {
                  ["Authorization"] = "Bearer " .. token,
                  ["Content-type" ] = "application/json",
                },
              })
              assert.are.same (status, 202)
            end)

            for _, method in ipairs { "DELETE", "HEAD", "GET", "OPTIONS", "PUT" } do
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

      end)

      describe ("with permission and authentication", function ()

        describe ("with admin authentication", function ()

          before_each (function ()
            local token  = Test.make_token (Test.identities.rahan)
            local status = request (app, project .. "/permissions/" .. naouna, {
              method  = "PUT",
              post    = Util.to_json { permission = "admin" },
              headers = {
                ["Authorization"] = "Bearer " .. token,
                ["Content-type" ] = "application/json",
              },
            })
            assert.are.same (status, 201)
          end)

          before_each (function ()
            local token  = Test.make_token (Test.identities.naouna)
            local status = request (app, route, {
              method  = "PUT",
              post    = Util.to_json { permission = "admin" },
              headers = {
                ['Authorization'] = "Bearer " .. token,
                ["Content-type" ] = "application/json",
              },
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

          for _, method in ipairs { "DELETE" } do
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
              token  = Test.make_token (Test.identities.rahan)
              status = request (app, project .. "/permissions/" .. naouna, {
                method  = method,
                headers = { Authorization = "Bearer " .. token},
              })
              assert.are.same (status, 204)
              token  = Test.make_token (Test.identities.rahan)
              status = request (app, project .. "/permissions/" .. rahan, {
                method  = method,
                headers = { Authorization = "Bearer " .. token},
              })
              assert.are.same (status, 409)
            end)
          end

          for _, method in ipairs { "PUT" } do
            it ("answers to " .. method, function ()
              local token  = Test.make_token (Test.identities.naouna)
              local status = request (app, route, {
                method  = method,
                post    = Util.to_json { permission = "admin" },
                headers = {
                  ['Authorization'] = "Bearer " .. token,
                  ["Content-type" ] = "application/json",
                },
              })
              assert.are.same (status, 202)
              status = request (app, route, {
                method  = method,
                post    = Util.to_json { permission = "something false" },
                headers = {
                  ['Authorization'] = "Bearer " .. token,
                  ["Content-type" ] = "application/json",
                },
              })
              assert.are.same (status, 400)
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

        for _, permission in ipairs { "write", "read", "none" } do
          describe ("with " .. permission .. " authentication", function ()

            before_each (function ()
              local token  = Test.make_token (Test.identities.rahan)
              local status = request (app, project .. "/permissions/" .. naouna, {
                method  = "PUT",
                post    = Util.to_json { permission = permission },
                headers = {
                  ["Authorization"] = "Bearer " .. token,
                  ["Content-type" ] = "application/json",
                },
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
        end

      end)

      describe ("with valid authentication", function ()

        describe ("with default admin permission", function ()

          before_each (function ()
            local token  = Test.make_token (Test.identities.rahan)
            local status = request (app, project .. "/permissions/user", {
              method  = "PUT",
              post    = Util.to_json { permission = "admin" },
              headers = {
                ["Authorization"] = "Bearer " .. token,
                ["Content-type" ] = "application/json",
              },
            })
            assert.are.same (status, 202)
          end)

          before_each (function ()
            local token  = Test.make_token (Test.identities.naouna)
            local status = request (app, route, {
              method  = "PUT",
              post    = Util.to_json { permission = "admin" },
              headers = {
                ['Authorization'] = "Bearer " .. token,
                ["Content-type" ] = "application/json",
              },
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

          for _, method in ipairs { "DELETE" } do
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
              token  = Test.make_token (Test.identities.rahan)
              status = request (app, project .. "/permissions/" .. rahan, {
                method  = method,
                headers = { Authorization = "Bearer " .. token},
              })
              assert.are.same (status, 409)
            end)
          end

          for _, method in ipairs { "PUT" } do
            it ("answers to " .. method, function ()
              local token  = Test.make_token (Test.identities.naouna)
              local status = request (app, route, {
                method  = method,
                post    = Util.to_json { permission = "admin" },
                headers = {
                  ['Authorization'] = "Bearer " .. token,
                  ["Content-type" ] = "application/json",
                },
              })
              assert.are.same (status, 202)
              status = request (app, route, {
                method  = method,
                post    = Util.to_json { permission = "something false" },
                headers = {
                  ['Authorization'] = "Bearer " .. token,
                  ["Content-type" ] = "application/json",
                },
              })
              assert.are.same (status, 400)
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

        for _, permission in ipairs { "write", "read", "none" } do
          describe ("with default " .. permission .. " permission", function ()

            before_each (function ()
              local token  = Test.make_token (Test.identities.rahan)
              local status = request (app, project .. "/permissions/user", {
                method  = "PUT",
                post    = Util.to_json { permission = permission },
                headers = {
                  ["Authorization"] = "Bearer " .. token,
                  ["Content-type" ] = "application/json",
                },
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

  end)

end)
