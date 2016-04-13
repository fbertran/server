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
  "lapis",
  "nginx-jwt",
}

build = {
  type    = "builtin",
  modules = {
    ["cosy.server.app"            ] = "src/cosy/server/app.lua",
    ["cosy.server.app.user"       ] = "src/cosy/server/app/user.lua",
    ["cosy.server.model"          ] = "src/cosy/server/model.lua",
    ["cosy.webclient"             ] = "src/cosy/webclient/init.lua",
    ["cosy.webclient.headbar"     ] = "src/cosy/webclient/headbar/init.lua",
    ["cosy.webclient.headbar.i18n"] = "src/cosy/webclient/headbar/i18n.lua",
  },
  install = {
    bin = {
      ["cosy-server"] = "src/cosy/server/run.lua",
      ["cosy-test"  ] = "src/cosy/server/test.lua",
    },
  },
}
