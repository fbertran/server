package = "cosy-server"
version = "master-1"
source  = {
  url = "git://github.com/saucisson/cosy-server"
}

description = {
  summary    = "CosyVerif: server",
  detailed   = [[
    Server of the CosyVerif platform.
  ]],
  homepage   = "http://www.cosyverif.org/",
  license    = "MIT/X11",
  maintainer = "Alban Linard <alban@linard.fr>",
}

dependencies = {
  "lua >= 5.1",
}

build = {
  type    = "builtin",
  modules = {
    ["cosy.server.app"   ] = "src/cosy/server/app.lua",
    ["cosy.server.models"] = "src/cosy/server/models.lua",
  },
  install = {
    bin = {
      ["cosy-server"] = "src/cosy/server/bin.lua",
    },
  },
}
