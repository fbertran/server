local Config = require "lapis.config"
local Url    = require "socket.url"

local branch = assert (os.getenv "COSY_BRANCH" or os.getenv "WERCKER_GIT_BRANCH")
if not branch or branch == "master" then
  branch = "latest"
end

local postgres_url = assert (Url.parse (os.getenv "POSTGRES_PORT"))
local redis_url    = assert (Url.parse (os.getenv "REDIS_PORT"   ))

local common = {
  host        = "localhost",
  port        = 8080,
  num_workers = assert (tonumber (os.getenv "NPROC")),
  code_cache  = "on",
  hashid      = {
    salt   = "cosyverif rocks",
    length = 8,
  },
  branch      = assert (branch),
  postgres    = {
    backend  = "pgmoon",
    host     = assert (postgres_url.host),
    port     = assert (postgres_url.port),
    user     = assert (os.getenv "POSTGRES_USER"    ),
    password = assert (os.getenv "POSTGRES_PASSWORD"),
    database = assert (os.getenv "POSTGRES_DATABASE"),
  },
  redis       = {
    host     = assert (redis_url.host),
    port     = assert (redis_url.port),
    database = 0,
  },
  auth0       = {
    domain        = assert (os.getenv "AUTH0_DOMAIN"),
    client_id     = assert (os.getenv "AUTH0_ID"    ),
    client_secret = assert (os.getenv "AUTH0_SECRET"),
    api_token     = assert (os.getenv "AUTH0_TOKEN" ),
  },
  docker      = {
    username = assert (os.getenv "DOCKER_USER"  ),
    api_key  = assert (os.getenv "DOCKER_SECRET"),
  },
}

Config ({ "test", "development", "production" }, common)
Config ({ "test", "development" }, {
  clean  = {
    delay = 1, -- second
  },
  editor = {
    timeout = 1, -- second
  },
})
Config ("production", {
  clean  = {
    delay = 300, -- second
  },
  editor = {
    timeout = 300, -- second
  },
})
