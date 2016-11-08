local Database = require "lapis.db"
local Config   = require "lapis.config".get ()
local Model    = require "cosy.server.model"
local Http     = require "cosy.server.http"
local Qless    = require "resty.qless"
local Mime     = require "mime"

local Clean = {}

function Clean.create ()
  local qless = Qless.new (Config.redis)
  local queue = qless.queues ["cosy"]
  queue:recur ("cosy.server.jobs.clean", {}, Config.clean.delay, {
    jid = "cosy.server.jobs.clean",
  })
end

function Clean.perform ()
  local services = Model.services:select (([[
    where id not in ( select service_id as id from resources  where service_id is not null
                union select service_id as id from executions where service_id is not null)
    and qless_job is not null
  ]]):gsub ("%s+", " "))
  for _, service in ipairs (services or {}) do
    if service.docker_url then
      local _, status = Http.json {
        url     = service.docker_url,
        method  = "DELETE",
        headers = {
          ["Authorization"] = "Basic " .. Mime.b64 (Config.docker.username .. ":" .. Config.docker.api_key),
        },
      }
      if (status >= 200 and status < 300) or status == 404 then
        service:delete ()
      end
    end
  end
  services = Model.services:select (([[
    where id in ( select service_id as id from resources  where service_id is not null
            union select service_id as id from executions where service_id is not null)
    and launched = true
  ]]):gsub ("%s+", " "))
  for _, service in ipairs (services or {}) do
    local info, status = Http.json {
      url     = service.docker_url,
      method  = "GET",
      headers = {
        ["Authorization"] = "Basic " .. Mime.b64 (Config.docker.username .. ":" .. Config.docker.api_key),
      },
    }
    if (status == 200 and info.state:lower () ~= "running")
    or  status == 404 then
      Database.update ("resources", {
        service_id = Database.NULL,
      }, {
        service_id = service.id,
      })
      Database.update ("executions", {
        service_id = Database.NULL,
      }, {
        service_id = service.id,
      })
    end
  end
end

return Clean
