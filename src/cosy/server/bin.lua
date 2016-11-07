#! /usr/bin/env lua

local Socket = require "socket"
local Url    = require "socket.url"
local Et     = require "etlua"
local Setenv = require "posix.stdlib".setenv

if not os.getenv "API_PORT" then
  local hostname, domainname
  do
    print ("Obtaining hostname...")
    local file = io.popen ("hostname", "r")
    hostname   = file:read "*l"
    file:close ()
  end
  do
    print ("Obtaining domainname...")
    local file = io.popen ("domainname", "r")
    domainname = file:read "*l"
    file:close ()
  end
  Setenv ("API_PORT", Url.build {
    scheme = "https",
    host   = hostname .. (domainname and "." .. domainname or ""),
  })
end

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
assert (os.execute (Et.render ([[ "<%- prefix %>/bin/lapis" migrate ]], {
  prefix = os.getenv "COSY_PREFIX",
})))

print "Starting server..."
assert (os.execute (Et.render ([[ "<%- prefix %>/bin/lapis" server ]], {
  prefix = os.getenv "COSY_PREFIX",
})))
