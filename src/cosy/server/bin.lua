#! /usr/bin/env lua

local Socket = require "socket"
local Url    = require "socket.url"
local Setenv = require "posix.stdlib".setenv

if not os.getenv "NPROC" then
  print ("Obtaining number of cores...")
  local file  = io.popen ("nproc", "r")
  local nproc = file:read "*l"
  file:close ()
  Setenv ("NPROC", nproc)
end

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
assert (os.execute [[ lapis migrate ]])

print "Starting server..."
assert (os.execute [[ lapis server ]])
