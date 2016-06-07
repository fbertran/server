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

local common = {
  hostname    = "127.0.0.1",
  port        = 8080,
  num_workers = 1,
  code_cache  = "on",
  auth0 = {
    domain        = assert (os.getenv "AUTH0_DOMAIN"),
    client_id     = assert (os.getenv "AUTH0_CLIENT"),
    client_secret = assert (os.getenv "AUTH0_SECRET"),
    api_token     = assert (os.getenv "AUTH0_API"),
    api_url       = "https://" .. assert (os.getenv "AUTH0_DOMAIN") .. "/api/v2",
  },
  redis = {
    host     = assert (os.getenv "REDIS_PORT_6379_TCP_ADDR"),
    port     = assert (os.getenv "REDIS_PORT_6379_TCP_PORT"),
    database = 1,
  },
  postgres = {
    backend  = "pgmoon",
    host     = assert (os.getenv "POSTGRES_PORT_5432_TCP_ADDR"),
    user     = assert (os.getenv "POSTGRES_ENV_POSTGRES_USER"),
    password = assert (os.getenv "POSTGRES_ENV_POSTGRES_PASSWORD"),
    database = assert (os.getenv "POSTGRES_ENV_POSTGRES_DATABASE"),
  },
  editor = {
    timeout = 5, -- seconds
  },
}

common.www_prefix = prefix .. "/share/cosy/www"

Config ({ "test", "development", "production" }, common)
