package = "cosy-server-env"
version = "master-1"
source  = {
  url = "git+https://github.com/cosyverif/server.git"
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
  "copas",
  "etlua",
  "lua-websockets",
  "luacheck",
  "luacov",
  "luacov-coveralls",
  "luafilesystem",
}

build = {
  type    = "builtin",
  modules = {},
}
