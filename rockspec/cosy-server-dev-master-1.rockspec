package = "cosy-server-dev"
version = "master-1"
source  = {
  url = "git://github.com/saucisson/cosy-server"
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
  "etlua",
  "luafilesystem",
  "luacov",
}

build = {
  type    = "builtin",
  modules = {},
}
