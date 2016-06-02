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
  "luarestyredis",
  "lua-resty-http",
}

build = {
  type    = "builtin",
  modules = {
    ["cosy.check.cli"                  ] = "src/cosy/check/cli.lua",
    ["cosy.i18n"                       ] = "src/cosy/i18n/init.lua",
    ["cosy.taskqueue.cli"              ] = "src/cosy/taskqueue/cli.lua",
    ["cosy.taskqueue.channels"         ] = "src/cosy/taskqueue/channels.lua",
    ["cosy.editor"                     ] = "src/cosy/editor/init.lua",
    ["cosy.editor.cli"                 ] = "src/cosy/editor/cli.lua",
    ["cosy.editor.resource"            ] = "src/cosy/editor/resource.lua",
    ["cosy.server"                     ] = "src/cosy/server/init.lua",
    ["cosy.server.before"              ] = "src/cosy/server/before.lua",
    ["cosy.server.users"               ] = "src/cosy/server/users/init.lua",
    ["cosy.server.users.auth0"         ] = "src/cosy/server/users/auth0.lua",
    ["cosy.server.users.user"          ] = "src/cosy/server/users/user.lua",
    ["cosy.server.projects"            ] = "src/cosy/server/projects/init.lua",
    ["cosy.server.projects.project"    ] = "src/cosy/server/projects/project.lua",
    ["cosy.server.projects.permissions"] = "src/cosy/server/projects/permissions.lua",
    ["cosy.server.projects.permission" ] = "src/cosy/server/projects/permission.lua",
    ["cosy.server.projects.resources"  ] = "src/cosy/server/projects/resources.lua",
    ["cosy.server.projects.resource"   ] = "src/cosy/server/projects/resource.lua",
    ["cosy.server.projects.stars"      ] = "src/cosy/server/projects/stars.lua",
    ["cosy.server.projects.tag"        ] = "src/cosy/server/projects/tag.lua",
    ["cosy.server.projects.tags"       ] = "src/cosy/server/projects/tags.lua",
    ["cosy.server.tags"                ] = "src/cosy/server/tags/init.lua",
    ["cosy.server.tags.tag"            ] = "src/cosy/server/tags/tag.lua",
    ["cosy.server.decorators"          ] = "src/cosy/server/decorators.lua",
    ["cosy.server.model"               ] = "src/cosy/server/model.lua",
    ["cosy.webclient"                  ] = "src/cosy/webclient/init.lua",
    ["cosy.webclient.headbar"          ] = "src/cosy/webclient/headbar/init.lua",
    ["cosy.webclient.headbar.i18n"     ] = "src/cosy/webclient/headbar/i18n.lua",
  },
  install = {
    bin = {
      ["cosy-check"    ] = "src/cosy/check/bin.lua",
      ["cosy-server"   ] = "src/cosy/server/bin.lua",
      ["cosy-taskqueue"] = "src/cosy/taskqueue/bin.lua",
      ["cosy-editor"   ] = "src/cosy/editor/bin.lua",
    },
  },
}
