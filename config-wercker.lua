local Config = require "lapis.config"

local prefix
do
  local path = package.searchpath ("cosy.server.app", package.path)
  local parts = {}
  for part in path:gmatch "[^/]+" do
    parts [#parts+1] = part
  end
  for _ = 1, 7 do
    parts [#parts] = nil
  end
  prefix = (path:find "^/" and "/" or "") .. table.concat (parts, "/")
end

Config ("test", {
  hostname = "cosyverif.dev",
  port     = 8080,
  postgres = {
    backend  = "pgmoon",
    host     = os.getenv "POSTGRES_PORT_5432_TCP_ADDR",
    user     = os.getenv "POSTGRES_ENV_POSTGRES_USER",
    password = os.getenv "POSTGRES_ENV_POSTGRES_PASSWORD",
    database = os.getenv "POSTGRES_ENV_POSTGRES_DATABASE",
  },
  measure_performance = true,
})

Config ("development", {
  hostname = "cosyverif.dev",
  port     = 8080,
  postgres = {
    backend  = "pgmoon",
    host     = os.getenv "POSTGRES_PORT_5432_TCP_ADDR",
    user     = os.getenv "POSTGRES_ENV_POSTGRES_USER",
    password = os.getenv "POSTGRES_ENV_POSTGRES_PASSWORD",
    database = os.getenv "POSTGRES_ENV_POSTGRES_DATABASE",
  },
})

Config ("production", {
  hostname    = "cosyverif.org",
  port        = 80,
  num_workers = 4,
  code_cache  = "on",
  postgres = {
    backend  = "pgmoon",
    host     = os.getenv "POSTGRES_PORT_5432_TCP_ADDR",
    user     = os.getenv "POSTGRES_ENV_POSTGRES_USER",
    password = os.getenv "POSTGRES_ENV_POSTGRES_PASSWORD",
    database = os.getenv "POSTGRES_ENV_POSTGRES_DATABASE",
  },
})

local common = {
  auth0 = {
    domain        = os.getenv "AUTH_DOMAIN",
    client_id     = os.getenv "AUTH_CLIENT",
    client_secret = os.getenv "AUTH_SECRET",
    api_token     = os.getenv "AUTH_API",
    api_url       = "https://" .. (os.getenv "AUTH_DOMAIN") .. "/api/v2",
  },
}

common.www_prefix  = prefix .. "/share/cosy/www"

Config ({ "test", "development", "production" }, common)
