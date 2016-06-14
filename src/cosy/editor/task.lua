local Config = require "lapis.config".get ()
local Http   = require "resty.http"
local Util   = require "lapis.util"
local Uuid   = require "resty.uuid"
local Et     = require "etlua"

local Task = {}

function Task.perform (job)
  local url = Et.render ("http<%- s %>://<%- host %>:<%- port %>", {
    s    = Config.docker.ssl and "s" or "",
    host = Config.docker.host,
    port = Config.docker.port,
  })
  local client  = Http.new ()
  local uuid    = Uuid.generate ()
  local id
  local ok, err = pcall (function ()
    local result = client:request_uri (url .. "/containers/create", {
      method  = "POST",
      headers = {
        ["Content-type"] = "application/json",
      },
      body    = Util.to_json {
        Cmd    = { "echo", job.data.token },
        Image  = "busybox",
        Labels = {
          ["cosy.uuid"] = uuid,
        },
      }
    })
    assert (result.status == 201)
    id     = Util.from_json (result.body).Id
    result = client:request_uri (url .. "/containers/" .. id .. "/start", {
      method = "POST",
    })
    assert (result.status == 204)
    repeat
      job:heartbeat ()
      result = client:request_uri (url .. "/containers/json?all=true", {
        method = "GET",
      })
      assert (result.status == 200)
      local finished
      for _, container in ipairs (Util.from_json (result.body)) do
        if container.Id == id then
          if container.State:lower () == "exited"
          or container.State:lower () == "stopped" then
            finished = true
          end
          break
        end
      end
      _G.ngx.sleep (1)
      -- _G.ngx.sleep (math.max (0, job:ttl () - 10))
    until finished
  end)
  do
    local result = client:request_uri (url .. "/containers/" .. id .. "&v=true&force=true", {
      method  = "DELETE",
    })
    assert (result.status == 204 or result.status == 404)
  end
  client:close ()
  if not ok then
    error (err)
  end
  return true
end

return Task
