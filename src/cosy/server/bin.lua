#! /usr/bin/env lua

local Socket = require "socket"
local Url    = require "socket.url"
local Et     = require "etlua"
local Setenv = require "posix.stdlib".setenv

-- FIXME:  nginx resolver does not seem to work within docker-compose or
-- docker-cloud, so we convert all service hostnames to ips before
-- launching the server.
for _, address in ipairs { "POSTGRES_PORT", "REDIS_PORT" } do
  local parsed = assert (Url.parse (os.getenv (address)))
  parsed.host  = assert (Socket.dns.toip (parsed.host))
  Setenv (address, Url.build (parsed))
end

print "Waiting for services to run..."
for _, address in ipairs { "POSTGRES_PORT", "REDIS_PORT" } do
  local parsed = assert (Url.parse (os.getenv (address)))
  local socket = Socket.tcp ()
  local i      = 0
  while not socket:connect (parsed.host, parsed.port) do
    if i > 10 then
      error (os.getenv (address) .. " is not reachable.")
    end
    os.execute [[ sleep 1 ]]
    i = i+1
  end
end

print "Applying database migrations..."
assert (os.execute (Et.render ([[ "<%- prefix %>/bin/lapis" migrate ]], {
  prefix = os.getenv "COSY_PREFIX",
})))

print "Starting server..."
if os.getenv "LAPIS_OPENRESTY" then
  assert (os.execute (Et.render ([[ "<%- prefix %>/bin/lapis" server ]], {
    prefix = os.getenv "COSY_PREFIX",
  })))
else
  assert (os.execute (Et.render ([[ LAPIS_OPENRESTY="<%- prefix %>/nginx/sbin/nginx" "<%- prefix %>/bin/lapis" server ]], {
    prefix = os.getenv "COSY_PREFIX",
  })))
end
