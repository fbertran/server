local Test = require "cosy.server.test"

describe ("route /tags", function ()
  Test.environment.use ()

  local Util
  local request
  local app

  before_each (function ()
    Util    = require "lapis.util"
    Test.clean_db ()
    request = Test.environment.request ()
    app     = Test.environment.app ()
  end)

  local projects = {}

  before_each (function ()
    for key, id in pairs (Test.identities) do
      local token  = Test.make_token (id)
      local status, result = request (app, "/users", {
        method  = "POST",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 201)
      result = Util.from_json (result)
      assert.is.not_nil (result.id)
      status, result = request (app, "/projects", {
        method  = "POST",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 201)
      result = Util.from_json (result)
      assert.is.not_nil (result.id)
      projects [key] = result.id
      status = request (app, "/projects/" .. result.id .. "/tags/" .. key, {
        method  = "PUT",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 201)
      status = request (app, "/projects/" .. result.id .. "/tags/shared", {
        method  = "PUT",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 201)
    end
  end)

  for _, method in ipairs { "HEAD", "OPTIONS" } do
    it ("answers to " .. method, function ()
      local status = request (app, "/tags", {
        method = method,
      })
      assert.are.same (status, 204)
    end)
  end

  for _, method in ipairs { "GET" } do
    it ("answers to " .. method, function ()
      local status, result = request (app, "/tags", {
        method = method,
      })
      assert.are.same (status, 200)
      result = Util.from_json (result)
      local count = 0
      for _ in pairs (Test.identities) do
        count = count + 1
      end
      assert.are.equal (#result, count+1)
    end)
  end

  for _, method in ipairs { "DELETE", "PATCH", "POST", "PUT" } do
    it ("answers to " .. method, function ()
      local status = request (app, "/tags", {
        method = method,
      })
      assert.are.same (status, 405)
    end)
  end

end)
