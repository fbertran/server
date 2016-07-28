#! /usr/bin/env lua

local Socket = require "socket"
local Url    = require "socket.url"
local Et     = require "etlua"
local Config = require "lapis.config".get ()

do -- Wait for database connection
  print "Waiting for database connection..."
  local parsed = Url.parse ("http://" .. Config.postgres.host)
  local socket = Socket.tcp ()
  local i = 0
  while not socket:connect (parsed.host or "localhost", parsed.port or 5432) do
    if i > 10 then
      error "Database is not reachable."
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
assert (os.execute (Et.render ([[ LAPIS_OPENRESTY="<%- prefix %>/nginx/sbin/nginx" "<%- prefix %>/bin/lapis" server ]], {
  prefix = os.getenv "COSY_PREFIX",
})))
