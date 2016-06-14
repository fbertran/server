local socket = require "socket"
local ssl    = require "ssl"

local params = {
  mode     = "client",
  -- protocol = "sslv23",
  -- key = "/etc/certs/clientkey.pem",
  -- certificate = "/etc/certs/client.pem",
  -- cafile = "/etc/certs/CA.pem",
  verify = "peer",
  options = { "all" }
}

local conn = socket.tcp ()
assert (conn:connect ("www.google.fr", 443))

-- TLS/SSL initialization
conn = ssl.wrap (conn, params)
assert (conn:dohandshake ())
assert (conn:close ())
