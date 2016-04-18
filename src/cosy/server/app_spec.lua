local Util   = require "lapis.util"
local Test   = require "cosy.server.test"

for name, environment in pairs (Test.environments) do
  local request = environment.request
  local app     = environment.app

  describe ("cosyverif api in " .. name .. " mode", function ()
    environment.use ()

    before_each (function ()
      Test.clean_db ()
    end)

    it ("accepts scenario #1", function ()
      local status, result
      local token = Test.make_token (Test.identities.rahan)
      -- Create the user:
      status, result = request (app, "/users", {
        method  = "POST",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 201)
      assert.is.not_nil (Util.from_json (result).id)
      local user = Util.from_json (result).id
      -- Update user info:
      status = request (app, "/users/" .. Test.identities.rahan, {
        method  = "PATCH",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 204)
      -- Create a project:
      status, result = request (app, "/projects", {
        method  = "POST",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 201)
      assert.is.not_nil (Util.from_json (result).id)
      local project = Util.from_json (result).id
      -- Star project:
      status = request (app, "/projects/" .. project .. "/stars", {
        method  = "PUT",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 201)
      -- Tag project:
      status = request (app, "/projects/" .. project .. "/tags/mytag", {
        method  = "PUT",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 201)
      -- Get user:
      status, result = request (app, "/users/" .. Test.identities.rahan, {
        method  = "GET",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 200)
      print (result)
      -- Get all users:
      status, result = request (app, "/users", {
        method  = "GET",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 200)
      print (result)
      -- Delete user:
      status = request (app, "/users/" .. Test.identities.rahan, {
        method  = "DELETE",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 204)
      -- Check that user has been deleted:
      status = request (app, "/projects/" .. user, {
        method  = "GET",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 404)
      -- Check that project has been deleted:
      status = request (app, "/projects/" .. project, {
        method  = "GET",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 404)
    end)

  end)

end
