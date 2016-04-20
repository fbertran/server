#! /usr/bin/env lua

local Et = require "etlua"

local path = package.searchpath ("cosy.server", package.path)
print (path)
local parts = {}
for part in path:gmatch "[^/]+" do
  parts [#parts+1] = part
end
for _ = 1, 6 do
  parts [#parts] = nil
end
local prefix = (path:find "^/" and "/" or "") .. table.concat (parts, "/")

os.execute (Et.render ([[
  LAPIS_OPENRESTY="<%= prefix %>/nginx/sbin/nginx" "<%= prefix %>/bin/lapis" server
]], {
  prefix = prefix,
}))
