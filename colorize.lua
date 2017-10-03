#! /usr/bin/env lua

local Arguments = require "argparse"
local Colors    = require 'ansicolors'

local parser = Arguments () {
  name        = "colorize",
  description = "Colorize luacov output depending on coverage level",
}
parser:option "--file" {
  description = "luacov output file",
  default     = "luacov.report.out",
}

local arguments = parser:parse ()
local file      = io.open (arguments.file)
local found_summary = false
while true do
  local line = file:read "*line"
  if not line then
    break
  elseif line:match "^Summary" then
    found_summary = true
    for _ = 1, 3 do
      file:read "*line"
    end
  elseif found_summary then
    local value = line:match "(%S+)%%"
    local color = "%{reset}"
    if value then
      value = tonumber (value)
      if value == 100 then
        color = "%{bright green}"
      elseif value < 100 and value >= 80 then
        color = "%{green}"
      elseif value < 80  and value >= 50 then
        color = "%{yellow}"
      elseif value < 50  and value >= 20 then
        color = "%{red}"
      else
        color = "%{bright red}"
      end
    end
    print (Colors (color .. line))
  end
end
file:close ()
