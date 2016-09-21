local Test      = require "cosy.server.test"
local Websocket = require "websocket"

-- FIXME: `lua-websockets` does not ship this file in luarocks,
-- so we add it instead in `package.preload`.
package.preload ["websocket.client_sync"] = function ()
  local socket = require "socket"
  local sync   = require "websocket.sync"
  local new = function (ws)
    ws =  ws or {}
    local result = {}
    result.sock_connect = function (self, host, port)
      self.sock = socket.tcp ()
      if ws.timeout ~= nil then
        self.sock:settimeout (ws.timeout)
      end
      local _, err = self.sock:connect (host,port)
      if err then
        self.sock:close ()
        return nil, err
      end
    end
    result.sock_send = function (self,...)
      return self.sock:send (...)
    end
    result.sock_receive = function (self,...)
      return self.sock:receive (...)
    end
    result.sock_close = function (self)
      self.sock:close ()
    end
    result = sync.extend (result)
    return result
  end
  return new
end

Test.environment.use ()

describe ("#resty route /projects/:project/resources/:resource/editor", function ()

  local app, request
  local project, project_token, route, naouna

  setup (function ()
    Test.clean_db ()
    request = Test.environment.request ()
    app     = Test.environment.app ()
  end)

  local function wsconnect (headers)
    for _ = 1, 30 do
      local client = Websocket.client.sync { timeout = 5 }
      if client:connect (headers ["Location"], "cosy") then
        return
      end
      os.execute [[ sleep 1 ]]
    end
    assert (false)
  end

  setup (function ()
    local token = Test.make_token (Test.identities.naouna)
    local status, result = request (app, "/", {
      method  = "GET",
      headers = { Authorization = "Bearer " .. token },
    })
    assert.are.same (status, 200)
    naouna = result.authentified.path:match "/users/(.*)"
    local _ = naouna
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
    project_token = Test.make_token (project)
    status, result = request (app, project .. "/resources", {
      method  = "POST",
      headers = {
        Authorization = "Bearer " .. token,
      },
    })
    assert.are.same (status, 201)
    route = result.path .. "/editor"
  end)

  after_each (function ()
    request (app, route, {
      method  = "DELETE",
      headers = { ["Authorization"] = "Bearer " .. project_token },
    })
  end)

  teardown (function ()
    while true do
      local status, info = request (app, "/", {
        method = "GET",
      })
      assert.are.equal (status, 200)
      if info.stats.dockers == 0 then
        break
      end
      os.execute [[ sleep 1 ]]
    end
  end)

  describe ("with project authentication and existing editor", function ()

    before_each (function ()
      local status = request (app, route, {
        method  = "GET",
        headers = { Authorization = "Bearer " .. project_token},
      })
      assert.are.same (status, 202)
    end)

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
        local status, headers, _
        repeat
          status, _, headers = request (app, route, {
            method  = method,
            headers = { Authorization = "Bearer " .. project_token},
          })
          assert.is_truthy (status == 202 or status == 302)
          if status ~= 302 then
            os.execute [[ sleep 1 ]]
          end
        until status == 302
        wsconnect (headers)
      end)
    end

    for _, method in ipairs { "PATCH", "POST", "PUT" } do
      it ("answers to " .. method, function ()
        local status = request (app, route, {
          method  = method,
          headers = { Authorization = "Bearer " .. project_token},
        })
        assert.are.same (status, 405)
      end)
    end

  end)

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

          -- for _, method in ipairs { "GET" } do
          --   it ("answers to " .. method, function ()
          --     local status = request (app, route, {
          --       method = method,
          --     })
          --     assert.are.same (status, 302)
          --     created = true
          --   end)
          -- end

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

          -- for _, method in ipairs { "GET" } do
          --   it ("answers to " .. method, function ()
          --     local token = Test.make_token (Test.identities.naouna)
          --     local status = request (app, route, {
          --       method  = method,
          --       headers = { Authorization = "Bearer " .. token},
          --     })
          --     assert.are.same (status, 302)
          --     created = true
          --   end)
          -- end

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
              local status = request (app, route, {
                method  = method,
                headers = { Authorization = "Bearer " .. token},
              })
              assert.are.same (status, 202)
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
          assert.are.same (status, 202)
        end)
      end

      for _, method in ipairs { "PATCH", "POST", "PUT" } do
        it ("answers to " .. method, function ()
          local status = request (app, route, {
            method  = method,
            headers = { Authorization = "Bearer " .. project_token},
          })
          assert.are.same (status, 405)
        end)
      end

    end)

  end)

end)
