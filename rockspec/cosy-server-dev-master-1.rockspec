package = "cosy-server-dev"
version = "master-1"
source  = {
  url = "git://github.com/cayonerie/server"
}

description = {
  summary    = "CosyVerif: server (dev dependencies)",
  detailed   = [[
    Development dependencies for cosy-server.
  ]],
  homepage   = "http://www.cosyverif.org/",
  license    = "MIT/X11",
  maintainer = "Alban Linard <alban@linard.fr>",
}

dependencies = {
  "lua >= 5.1",
  "argparse",
  "ansicolors",
  "busted",
  "cluacov",
  "etlua",
  "luacheck",
  "luacov",
  "luacov-coveralls",
  "luafilesystem",
}

build = {
  type    = "builtin",
  modules = {},
}
