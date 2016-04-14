local Db = require "lapis.db"

local environments = {}
environments.server = {
  app     = nil,
  use     = require "lapis.spec".use_test_server,
  request = function (_, ...)
    return require "lapis.spec.server".request (...)
  end,
}
-- if not os.getenv "Apple_PubSub_Socket_Render" then
--   environments.mock = {
--     app     = require "cosy.server.app",
--     use     = require "lapis.spec".use_test_env,
--     request = require "lapis.spec.request".mock_request,
--   }
-- end

for name, environment in pairs (environments) do
  local request = environment.request
  local app     = environment.app

  describe ("cosyverif api in " .. name .. " mode", function ()
    environment.use ()

    before_each (function ()
      Db.delete "users"
      Db.delete "projects"
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
