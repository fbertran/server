local Instance = require "cosy.server.instance"
local Test     = require "cosy.server.test"

Test.environment.use ()

describe ("#resty #instance", function ()

  it ("should work", function ()
    local instance = Instance.create ()
    local server = instance.server
    instance:delete ()
    assert.is_truthy (server)
  end)

end)
