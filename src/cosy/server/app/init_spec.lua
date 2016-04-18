local Test = require "cosy.server.test"

for name, environment in pairs (Test.environments) do
  local request = environment.request
  local app     = environment.app

  describe ("cosyverif api in " .. name .. " mode", function ()
    environment.use ()

    before_each (function ()
      Test.clean_db ()
    end)

    describe ("route '/'", function ()

      it ("answers to HEAD", function ()
        local status = request (app, "/")
        assert.are.same (status, 200)
      end)

      it ("answers to GET", function ()
        local status = request (app, "/")
        assert.are.same (status, 200)
      end)

      it ("answers to OPTIONS", function ()
        local status = request (app, "/")
        assert.are.same (status, 200)
      end)

      for _, method in ipairs { "DELETE", "POST", "PUT" } do
        it ("does not answer to " .. method, function ()
          local status = request (app, "/", {
            method = method,
          })
          assert.are.same (status, 405)
        end)
      end

    end)

  end)

end
