local Test = require "cosy.server.test"
local Et   = require "etlua"

describe ("#current client", function ()
  Test.environment.use ()

  local request

  before_each (function ()
    Test.clean_db ()
    local app    = Test.environment.app    ()
    local server = Test.environment.server ()
    local req    = Test.environment.request ()
    if server then
      local url = Et.render ("http://<%- host %>:<%- port %>", {
        host = "localhost",
        port = server.app_port,
      })
      request = function (u, options)
        return req (nil, url .. u, options)
      end
    else
      request = function (u, options)
        return req (app, u, options)
      end
    end
  end)

  it ("can be required", function ()
    assert.has.no.errors (function ()
      require "cosy.client"
    end)
  end)

  it ("can be instantiated without authentication", function ()
    assert.has.no.errors (function ()
      local Client = require "cosy.client"
      Client.new {
        server  = "/",
        request = request,
      }
    end)
  end)

  it ("can be instantiated with authentication", function ()
    local token = Test.make_token (Test.identities.rahan)
    assert.has.no.errors (function ()
      local Client = require "cosy.client"
      Client.new {
        server  = "/",
        request = request,
        token   = token,
      }
    end)
  end)

  it ("cannot be instantiated with invalid authentication", function ()
    local token = Test.make_false_token (Test.identities.rahan)
    assert.has.errors (function ()
      local Client = require "cosy.client"
      Client.new {
        server  = "/",
        request = request,
        token   = token,
      }
    end)
  end)

end)
