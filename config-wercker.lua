local config = require "lapis.config"

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

config ("test", {
  hostname = "cosyverif.dev",
  port     = 8080,
  postgres = {
    backend  = "pgmoon",
    host     = os.getenv "POSTGRES_PORT",
    user     = os.getenv "POSTGRES_USER",
    password = os.getenv "POSTGRES_PASSWORD",
    database = os.getenv "POSTGRES_DB",
  },
  measure_performance = true,
})

config ("development", {
  hostname = "cosyverif.dev",
  port     = 8080,
  postgres = {
    backend  = "pgmoon",
    host     = os.getenv "POSTGRES_PORT",
    user     = os.getenv "POSTGRES_USER",
    password = os.getenv "POSTGRES_PASSWORD",
    database = os.getenv "POSTGRES_DB",
  },
})

config ("production", {
  hostname    = "cosyverif.org",
  port        = 80,
  num_workers = 4,
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
}

common.www_prefix  = prefix .. "/share/cosy/www"

config ({ "test", "development", "production" }, common)
