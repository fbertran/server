local Et = require "etlua"

local Task = {}

local prefix
do
  local path = package.searchpath ("cosy.check.cli", package.path)
  local parts = {}
  for part in path:gmatch "[^/]+" do
    parts [#parts+1] = part
  end
  for _ = 1, 6 do
    parts [#parts] = nil
  end
  prefix = (path:find "^/" and "/" or "") .. table.concat (parts, "/")
end

function Task.perform (job)
  os.execute (Et.render ([[
    "<%= prefix %>/bin/cosy-editor" "<%= token %>" &
  ]], {
    prefix = prefix,
    token  = job.data.token,
  }))
  return true
end

return Task
