local Config = require "lapis.config".get ()
local Http   = require "cosy.server.http"
local Mime   = require "mime"

local Docker = {}

function Docker.delete (docker_url)
  local headers = {
    ["Authorization"] = "Basic " .. Mime.b64 (Config.docker.username .. ":" .. Config.docker.api_key),
  }
  while true do
    local _, deleted_status = Http.json {
      url     = docker_url,
      method  = "DELETE",
      headers = headers,
    }
    if deleted_status == 202 or deleted_status == 404 then
      break
    elseif _G.ngx and _G.ngx.sleep then
      _G.ngx.sleep (1)
    else
      os.execute "sleep 1"
    end
  end
end


return Docker
