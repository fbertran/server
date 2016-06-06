local Copas     = require "copas.ev"
Copas:make_default ()
local Websocket = require "websocket"
local Test      = require "cosy.server.test"
local Json      = require "cjson"
local request   = require "socket.http".request
local Ltn12     = require "ltn12"

local token = Test.make_token (Test.identities.rahan)
local project, resource

do
  local response = {}
  local _, status = request {
    url     = "http://api.cosyverif.dev:8080/projects",
    method  = "POST",
    sink    = Ltn12.sink.table (response),
    headers = {
      Authorization = "Bearer " .. token,
    },
  }
  response = table.concat (response)
  assert.are.same (status, 201)
  project = Json.decode (response)
  assert.is.not_nil (project.id)
end

do
  local response = {}
  local _, status = request {
    url     = "http://api.cosyverif.dev:8080/projects/" .. project.id .. "/resources",
    method  = "POST",
    sink    = Ltn12.sink.table (response),
    headers = {
      Authorization = "Bearer " .. token,
    },
  }
  response = table.concat (response)
  assert.are.same (status, 201)
  resource = Json.decode (response)
  assert.is.not_nil (resource.id)
end

do
  local url = "ws://api.cosyverif.dev:8080/projects/" .. project.id .. "/resources/" .. resource.id .. "/editor"
  print (url)
  local _, status = request {
    url     = url,
    method  = "GET",
    headers = {
      Authorization = "Bearer " .. token,
    },
  }
  print (status)
  Copas.addthread (function ()
    local ws = Websocket.client.copas {}
    print (ws:connect (url, "cosy"))
    ws:close ()
  end)
  Copas.loop ()
end
