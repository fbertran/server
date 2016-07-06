local Arguments = require "argparse"
local Colors    = require 'ansicolors'
local Et        = require "etlua"
local Lfs       = require "lfs"
local Reporter  = require "luacov.reporter"
local prefix
local source
local rocks = {}

do
  local path = package.searchpath ("cosy.server.check.cli", package.path)
  if path:sub (1, 2) == "./" then
    path = Lfs.currentdir () .. "/" .. path:sub (3)
  end
  local parts = {}
  for part in path:gmatch "[^/]+" do
    parts [#parts+1] = part
  end
  for _ = 1, 3 do
    parts [#parts] = nil
  end
  source = (path:find "^/" and "/" or "") .. table.concat (parts, "/")
  for _ = 1, 4 do
    parts [#parts] = nil
  end
  prefix = (path:find "^/" and "/" or "") .. table.concat (parts, "/")
  local rockspath = prefix .. "/lib/luarocks/rocks/"
  for subpath in Lfs.dir (rockspath) do
    if subpath:match "^cosy"
    and Lfs.attributes (rockspath .. subpath, "mode") == "directory" then
      rocks [#rocks+1] = rockspath .. subpath
    end
  end
end

local parser = Arguments () {
  name        = "cosy-check-server",
  description = "Perform various checks on the cosy server sources",
}
parser:option "--prefix" {
  description = "install prefix",
  default     = prefix,
}
parser:option "--output" {
  description = "output directory",
  default     = "output",
}
parser:option "--tags" {
  description = "busted tags",
  default     = nil,
}


local arguments = parser:parse ()

function _G.string.split (s, delimiter)
  local result = {}
  for part in s:gmatch ("[^" .. delimiter .. "]+") do
    result [#result+1] = part
  end
  return result
end

local status = true

Lfs.mkdir (arguments.output)


-- luacheck
-- ========

do
  status = os.execute (Et.render ([[
    "<%- prefix %>/bin/luacheck" --std max --std +busted "<%- source %>"
  ]], {
    prefix = prefix,
    source = source,
  })) == 0 and status
end

-- busted
-- ======
do
  os.execute [[
    rm -f luacov.*
  ]]
  status = os.execute (Et.render ([[
    LAPIS_OPENRESTY="<%- prefix %>/nginx/sbin/nginx" "<%- prefix %>/bin/busted" "<%- tags %>" --verbose src/
  ]], {
    prefix = prefix,
    tags   = arguments.tags and "--tags=" .. arguments.tags,
  })) == 0 and status
  status = os.execute (Et.render ([[
    LAPIS_OPENRESTY="<%- prefix %>/nginx/sbin/nginx" RUN_COVERAGE=true "<%- prefix %>/bin/busted" --verbose --coverage "<%- tags %>" --verbose src/
  ]], {
    prefix = prefix,
    tags   = arguments.tags and "--tags=" .. arguments.tags,
  })) == 0 and status
  print ()
end

-- luacov
-- ======

do
  Reporter.report ()

  local report = {}
  Lfs.mkdir "coverage"

  local file      = "luacov.report.out"
  local output    = nil
  local in_header = false
  local current
  for line in io.lines (file) do
    if     not in_header
    and    line:find ("==============================================================================") == 1
    then
      in_header = true
      if output then
        output:close ()
        output = nil
      end
    elseif in_header
    and    line:find ("==============================================================================") == 1
    then
      in_header = false
    elseif in_header
    then
      current = line
      if current ~= "Summary" then
        local filename = line:match "/(cosy/.-%.lua)$"
        if filename and filename:match "^cosy" then
          local parts = {}
          for part in filename:gmatch "[^/]+" do
            parts [#parts+1] = part
            if not part:match ".lua$" then
              Lfs.mkdir ("coverage/" .. table.concat (parts, "/"))
            end
          end
          output = io.open ("coverage/" .. table.concat (parts, "/"), "w")
        end
      end
    elseif output then
      output:write (line .. "\n")
    else
      local filename = line:match "src/(cosy/.-%.lua)"
      if filename and filename:match "^cosy" then
        line = line:gsub ("\t", " ")
        local parts = line:split " "
        if #parts == 4 and parts [4] ~= "" then
          report [filename] = tonumber (parts [4]:match "([0-9%.]+)%%")
        end
      end
    end
  end
  if output then
    output:close ()
  end

  local max_size = 0
  for k, _ in pairs (report) do
    max_size = math.max (max_size, #k)
  end
  max_size = max_size + 3

  local keys = {}
  for k, _ in pairs (report) do
    keys [#keys + 1] = k
  end
  table.sort (keys)

  for i = 1, #keys do
    local k = keys   [i]
    local v = report [k]
    if not k:match "/share/lua/" and not k:match "_spec.lua" then
      local color
      if v == 100 then
        color = "%{bright green}"
      elseif v < 100 and v >= 90 then
        color = "%{green}"
      elseif v < 90 and v >= 80 then
        color = "%{yellow}"
      elseif v < 80 and v >= 50 then
        color = "%{red}"
      else
        color = "%{bright red}"
      end
      local line = k
      for _ = #k, max_size do
        line = line .. " "
      end
      print ("Coverage " .. line .. Colors (color .. string.format ("%3d", v) .. "%"))
    end
  end
end

print ()

-- shellcheck
-- ==========

do
  -- We know that we are in developper mode. Thus, there is a link to the user
  -- sources of cosy library.
  if os.execute "command -v shellcheck > /dev/null 2>&1" == 0 then
    local s = os.execute (Et.render ([[
      if [ -d bin ]; then
        . "<%- prefix %>/bin/realpath.sh"
        shellcheck $(realpath bin/*)
      fi
    ]], {
      prefix = prefix,
    }))
    if s == 0 then
      print (Colors ("Shellcheck detects %{bright green}no problems%{reset}."))
    end
    status = s == 0 and status
  end
end

os.exit (status and 0 or 1)
