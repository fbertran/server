local Config = require "lapis.config"

local prefix
do
  local path = package.searchpath ("cosy.server", package.path)
  local parts = {}
  for part in path:gmatch "[^/]+" do
    parts [#parts+1] = part
  end
  for _ = 1, 6 do
    parts [#parts] = nil
  end
  prefix = (path:find "^/" and "/" or "") .. table.concat (parts, "/")
end

Config ("test", {
  hostname    = "cosyverif.dev",
  port        = 8080,
  num_workers = 4,
  code_cache  = "on",
})

Config ("development", {
  hostname = "cosyverif.dev",
  port     = 8080,
  measure_performance = true,
})

Config ("production", {
  hostname    = "cosyverif.org",
  port        = 80,
  code_cache  = "on",
})

local common = {
  auth0 = {
    domain        = os.getenv "AUTH0_DOMAIN",
    client_id     = os.getenv "AUTH0_CLIENT",
    client_secret = os.getenv "AUTH0_SECRET",
    api_token     = os.getenv "AUTH0_API",
    api_url       = "https://" .. (os.getenv "AUTH0_DOMAIN") .. "/api/v2",
  },
  redis = {
    host     = (os.getenv "WERCKER_REDIS_URL"):match "redis://(.*):[%d]+",
    port     = os.getenv "WERCKER_REDIS_PORT",
    database = 1,
  },
  postgres = {
    backend  = "pgmoon",
    host     = os.getenv "POSTGRES_PORT_5432_TCP_ADDR",
    user     = os.getenv "POSTGRES_ENV_POSTGRES_USER",
    password = os.getenv "POSTGRES_ENV_POSTGRES_PASSWORD",
    database = os.getenv "POSTGRES_ENV_POSTGRES_DATABASE",
  },
}

common.www_prefix     = prefix .. "/share/cosy/www"
common.redis_host     = common.redis.host
common.redis_port     = common.redis.port
common.redis_database = common.redis.database

Config ({ "test", "development", "production" }, common)
