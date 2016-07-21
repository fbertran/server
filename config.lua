local config = require "lapis.config"

local hostname = assert (os.getenv "COSY_HOST")

local common = {
  hostname    = assert (hostname:match "[^:]+"),
  port        = assert (tonumber (hostname:match ":(%d+)")),
  num_workers = 4,
  code_cache  = "on",
  postgres = {
    backend  = "pgmoon",
    host     = assert (os.getenv "POSTGRES_HOST"),
    user     = assert (os.getenv "POSTGRES_USER"),
    password = assert (os.getenv "POSTGRES_PASSWORD"),
    database = assert (os.getenv "POSTGRES_DATABASE"),
  },
  auth0 = {
    domain        = assert (os.getenv "AUTH0_DOMAIN"),
    client_id     = assert (os.getenv "AUTH0_ID"),
    client_secret = assert (os.getenv "AUTH0_SECRET"),
    api_token     = assert (os.getenv "AUTH0_TOKEN"),
  },
  docker = {
    username = assert (os.getenv "DOCKER_USER"),
    api_key  = assert (os.getenv "DOCKER_SECRET"),
  },
  editor = {
    timeout = 1,
  },
}

config ({ "test", "development", "production" }, common)
