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
  "i18n",
  "jwt",
  "lapis",
  "layeredata",
}

build = {
  type    = "builtin",
  modules = {
    ["cosy.check.cli"             ] = "src/cosy/check/cli.lua",
    ["cosy.i18n"                  ] = "src/cosy/i18n/init.lua",
    ["cosy.server.app"            ] = "src/cosy/server/app/init.lua",
    ["cosy.server.app.auth0"      ] = "src/cosy/server/app/auth0.lua",
    ["cosy.server.app.user"       ] = "src/cosy/server/app/user.lua",
    ["cosy.server.app.project"    ] = "src/cosy/server/app/project.lua",
    ["cosy.server.decorators"     ] = "src/cosy/server/decorators.lua",
    ["cosy.server.model"          ] = "src/cosy/server/model.lua",
    ["cosy.webclient"             ] = "src/cosy/webclient/init.lua",
    ["cosy.webclient.headbar"     ] = "src/cosy/webclient/headbar/init.lua",
    ["cosy.webclient.headbar.i18n"] = "src/cosy/webclient/headbar/i18n.lua",
  },
  install = {
    bin = {
      ["cosy-server"] = "src/cosy/server/bin.lua",
      ["cosy-check" ] = "src/cosy/check/bin.lua",
    },
  },
}
