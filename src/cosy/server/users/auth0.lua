local Util   = require "lapis.util"
local Config = require "lapis.config".get ()
local Ltn12  = require "ltn12"
local Http   = Config._name == "test"
           and require "ssl.https"
            or require "lapis.nginx.http"

return function (url)
  local result = {}
  local _, status = Http.request {
    url      = Config.auth0.api_url .. url,
    sink     = Ltn12.sink.table (result),
    headers  = {
      Authorization = "Bearer " .. Config.auth0.api_token,
    },
  }
  return Util.from_json (table.concat (result)), status
end
