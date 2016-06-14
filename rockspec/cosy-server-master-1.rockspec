package = "cosy-server"
version = "master-1"
source  = {
  url = "git://github.com/cayonerie/server"
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
--  "lua-resty-auto-ssl",
  "lua-resty-http",
  "lua-resty-qless",
  "lua-resty-redis-connector",
  "lua-resty-uuid",
}

build = {
  type    = "builtin",
  modules = {
    ["cosy.check.cli"                  ] = "src/cosy/check/cli.lua",
    ["cosy.i18n"                       ] = "src/cosy/i18n/init.lua",
    ["cosy.util"                       ] = "src/cosy/util.lua",
    ["cosy.editor.task"                ] = "src/cosy/editor/task.lua",
    ["cosy.server"                     ] = "src/cosy/server/init.lua",
    ["cosy.server.worker"              ] = "src/cosy/server/worker.lua",
    ["cosy.server.before"              ] = "src/cosy/server/before.lua",
    ["cosy.server.quote"               ] = "src/cosy/server/quote.lua",
    ["cosy.server.users"               ] = "src/cosy/server/users/init.lua",
    ["cosy.server.users.auth0"         ] = "src/cosy/server/users/auth0.lua",
    ["cosy.server.users.user"          ] = "src/cosy/server/users/user.lua",
    ["cosy.server.projects"            ] = "src/cosy/server/projects/init.lua",
    ["cosy.server.projects.editor"     ] = "src/cosy/server/projects/editor.lua",
    ["cosy.server.projects.project"    ] = "src/cosy/server/projects/project.lua",
    ["cosy.server.projects.permission" ] = "src/cosy/server/projects/permission.lua",
    ["cosy.server.projects.permissions"] = "src/cosy/server/projects/permissions.lua",
    ["cosy.server.projects.resource"   ] = "src/cosy/server/projects/resource.lua",
    ["cosy.server.projects.resources"  ] = "src/cosy/server/projects/resources.lua",
    ["cosy.server.projects.stars"      ] = "src/cosy/server/projects/stars.lua",
    ["cosy.server.projects.tag"        ] = "src/cosy/server/projects/tag.lua",
    ["cosy.server.projects.tags"       ] = "src/cosy/server/projects/tags.lua",
    ["cosy.server.tags"                ] = "src/cosy/server/tags/init.lua",
    ["cosy.server.tags.tag"            ] = "src/cosy/server/tags/tag.lua",
    ["cosy.server.decorators"          ] = "src/cosy/server/decorators.lua",
    ["cosy.server.model"               ] = "src/cosy/server/model.lua",
    ["cosy.server.worker"              ] = "src/cosy/server/worker.lua",
    ["cosy.webclient"                  ] = "src/cosy/webclient/init.lua",
    ["cosy.webclient.headbar"          ] = "src/cosy/webclient/headbar/init.lua",
    ["cosy.webclient.headbar.i18n"     ] = "src/cosy/webclient/headbar/i18n.lua",
  },
  install = {
    bin = {
      ["cosy-check" ] = "src/cosy/check/bin.lua",
      ["cosy-server"] = "src/cosy/server/bin.lua",
    },
  },
}
