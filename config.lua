local Config = require "lapis.config"

local hostname = assert (os.getenv "COSY_HOST")
local branch   = assert (os.getenv "COSY_BRANCH" or os.getenv "WERCKER_GIT_BRANCH")
if not branch or branch == "master" then
  branch = "latest"
end

local common = {
  resolvers   = assert (os.getenv "RESOLVERS"),
  hostname    = assert (hostname:match "[^:]+"),
  port        = assert (tonumber (hostname:match ":(%d+)")),
  num_workers = os.getenv "CI" and 1 or 4,
  code_cache  = "on",
  branch      = assert (branch),
  postgres    = {
    backend  = "pgmoon",
    host     = assert (os.getenv "POSTGRES_PORT":match "tcp://([^:]+):%d+"),
    port     = assert (os.getenv "POSTGRES_PORT":match "tcp://[^:]+:(%d+)"),
    user     = assert (os.getenv "POSTGRES_USER"    ),
    password = assert (os.getenv "POSTGRES_PASSWORD"),
    database = assert (os.getenv "POSTGRES_DATABASE"),
  },
  redis       = {
    host    = assert (os.getenv "REDIS_PORT":match "tcp://([^:]+):%d+"),
    port    = assert (os.getenv "REDIS_PORT":match "tcp://[^:]+:(%d+)"),
    timeout = 500,
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
  editor      = {
    timeout = 60,
  },
}

Config ({ "test", "development", "production" }, common)
