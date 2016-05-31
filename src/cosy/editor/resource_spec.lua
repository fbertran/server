local Et        = require "etlua"
local Test      = require "cosy.server.test"
local Config    = require "lapis.config".get ()
local Copas     = require "copas.ev"
Copas:make_default ()
local Websocket = require "websocket"

describe ("route /projects/:project/resources/:resource", function ()

  Test.environment.use ()

  local Util, app, server, project, route, request, naouna

  before_each (function ()
    Util    = require "lapis.util"
    Test.clean_db ()
    request = Test.environment.request ()
    app     = Test.environment.app ()
    server  = Test.environment.server ()
  end)

  before_each (function ()
    if not Test.environment.nginx then
      return
    end
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
    if not Test.environment.nginx then
      return
    end
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
    status, result = request (app, project .. "/resources", {
      method  = "POST",
      headers = {
        Authorization = "Bearer " .. token,
      },
    })
    assert.are.same (status, 201)
    result = Util.from_json (result)
    assert.is.not_nil (result.id)
    route   = project.. "/resources/" .. result.id
  end)

  it ("#current ???", function ()
    if not Test.environment.nginx then
      return
    end
    -- for k, v in pairs (server) do
    --   print (k, v)
    -- end
    Config.port = server.app_port
    local url = Et.render ([[http://api.<%= hostname %>:<%= port %>/]], Config)
    print (url)
    print (url, request (app, url))
    url = Et.render ([[ws://api.<%= hostname %>:<%= port %>]], Config)
    print (url .. route)
    Copas.addthread (function ()
      local ws = Websocket.client.copas {}
      print (ws:connect (url .. route))
      ws:close ()
    end)
    Copas.loop ()
  end)

end)
