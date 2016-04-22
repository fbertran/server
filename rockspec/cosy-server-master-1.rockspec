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
  "copas-ev",
  "i18n",
  "jwt",
  "lapis",
  "layeredata",
  "lua-websockets",
  "lustache",
  "redis-lua",
}

build = {
  type    = "builtin",
  modules = {
    ["cosy.check.cli"                ] = "src/cosy/check/cli.lua",
    ["cosy.i18n"                     ] = "src/cosy/i18n/init.lua",
    ["cosy.runner.cli"               ] = "src/cosy/runner/cli.lua",
    ["cosy.updater.cli"              ] = "src/cosy/updater/cli.lua",
    ["cosy.server"                   ] = "src/cosy/server/init.lua",
    ["cosy.server.auth0"             ] = "src/cosy/server/auth0.lua",
    ["cosy.server.users"             ] = "src/cosy/server/users.lua",
    ["cosy.server.projects"          ] = "src/cosy/server/projects/init.lua",
    ["cosy.server.projects.resources"] = "src/cosy/server/projects/resources.lua",
    ["cosy.server.projects.stars"    ] = "src/cosy/server/projects/stars.lua",
    ["cosy.server.projects.tags"     ] = "src/cosy/server/projects/tags.lua",
    ["cosy.server.tags"              ] = "src/cosy/server/tags.lua",
    ["cosy.server.decorators"        ] = "src/cosy/server/decorators.lua",
    ["cosy.server.model"             ] = "src/cosy/server/model.lua",
    ["cosy.webclient"                ] = "src/cosy/webclient/init.lua",
    ["cosy.webclient.headbar"        ] = "src/cosy/webclient/headbar/init.lua",
    ["cosy.webclient.headbar.i18n"   ] = "src/cosy/webclient/headbar/i18n.lua",
  },
  install = {
    bin = {
      ["cosy-check"  ] = "src/cosy/check/bin.lua",
      ["cosy-server" ] = "src/cosy/server/bin.lua",
      ["cosy-runner" ] = "src/cosy/runner/bin.lua",
      ["cosy-updater"] = "src/cosy/updater/bin.lua",
    },
  },
}
