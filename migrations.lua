local Schema   = require "lapis.db.schema"
local Database = require "lapis.db"

local identifier   = [[ bigint PRIMARY KEY DEFAULT nextval('identifiers') ]]
local foreign      = [[ bigint NOT NULL ]]
local foreign_null = [[ bigint DEFAULT NULL ]]
local identity     = [[ identity NOT NULL ]]
local permission   = [[ permission NOT NULL ]]

return {
  function ()
    Database.query [[
      CREATE SEQUENCE identifiers
    ]]
  end,
  function ()
    Database.query [[
      CREATE TYPE identity AS ENUM ('user', 'project')
    ]]
    Schema.create_table ("identities", {
      { "identifier", Schema.types.text { null = true } },
      { "id"        , [[ bigint UNIQUE NOT NULL ]]      },
      { "type"      , identity                          },
    })
  end,
  function ()
    Schema.create_table ("users", {
      { "id"        , identifier           },
      { "path"      , Schema.types.text    { null = true } },
      { "email"     , Schema.types.text    { null = true } },
      { "name"      , Schema.types.text    { null = true } },
      { "picture"   , Schema.types.text    { null = true } },
      { "nickname"  , Schema.types.text    },
      { "reputation", Schema.types.integer },
      { "created_at", Schema.types.time    },
      { "updated_at", Schema.types.time    },
    })
  end,
  function ()
    Database.query [[
      CREATE TYPE permission AS ENUM ('none', 'read', 'write', 'admin')
    ]]
    Schema.create_table ("projects", {
      { "id"                  , identifier        },
      { "path"                , Schema.types.text { null = true } },
      { "name"                , Schema.types.text { null = true } },
      { "description"         , Schema.types.text { null = true } },
      { "permission_anonymous", permission        },
      { "permission_user"     , permission        },
      { "created_at"          , Schema.types.time },
      { "updated_at"          , Schema.types.time },
    })
    Schema.create_table ("tags", {
      { "id"        , Schema.types.text },
      { "user_id"   , foreign           },
      { "project_id", foreign           },
      { "created_at", Schema.types.time },
      { "updated_at", Schema.types.time },
      [[ PRIMARY KEY ("id", "user_id", "project_id") ]],
      [[ FOREIGN KEY ("user_id"   ) REFERENCES "users"    ("id") ON DELETE CASCADE ]],
      [[ FOREIGN KEY ("project_id") REFERENCES "projects" ("id") ON DELETE CASCADE ]],
    })
    Schema.create_table ("stars", {
      { "user_id"   , foreign           },
      { "project_id", foreign           },
      { "created_at", Schema.types.time },
      { "updated_at", Schema.types.time },
      [[ PRIMARY KEY ("user_id", "project_id") ]],
      [[ FOREIGN KEY ("user_id"   ) REFERENCES "users"    ("id") ON DELETE CASCADE ]],
      [[ FOREIGN KEY ("project_id") REFERENCES "projects" ("id") ON DELETE CASCADE ]],
    })
  end,
  function ()
    Schema.create_table ("permissions", {
      { "identity_id", foreign           },
      { "project_id" , foreign           },
      { "permission" , permission        },
      { "created_at" , Schema.types.time },
      { "updated_at" , Schema.types.time },
      [[ PRIMARY KEY ("identity_id", "project_id") ]],
      [[ FOREIGN KEY ("project_id" ) REFERENCES "projects"   ("id") ON DELETE CASCADE ]],
      [[ FOREIGN KEY ("identity_id") REFERENCES "identities" ("id") ON DELETE CASCADE ]],
    })
  end,
  function ()
    Schema.create_table ("services", {
      { "id"        , identifier },
      { "launched"  , Schema.types.boolean { default = false } },
      { "path"      , Schema.types.text                 },
      { "docker_url", Schema.types.text { null = true } },
      { "editor_url", Schema.types.text { null = true } },
      { "qless_job" , Schema.types.text { null = true } },
      { "created_at", Schema.types.time                 },
      { "updated_at", Schema.types.time                 },
    })
  end,
  function ()
    Schema.create_table ("resources", {
      { "id"           , identifier },
      { "path"         , Schema.types.text   { null = true } },
      { "project_id"   , foreign             },
      { "name"         , Schema.types.text   { null = true } },
      { "description"  , Schema.types.text   { null = true } },
      { "service_id"   , foreign_null        },
      { "data"         , Schema.types.text   },
      { "created_at"   , Schema.types.time   },
      { "updated_at"   , Schema.types.time   },
      [[ FOREIGN KEY ("project_id") REFERENCES "projects" ("id") ON DELETE CASCADE  ]],
      [[ FOREIGN KEY ("service_id") REFERENCES "services" ("id") ON DELETE SET NULL ]],
    })
    Schema.create_table ("histories", {
      { "id"         , identifier        },
      { "user_id"    , foreign           },
      { "resource_id", foreign           },
      { "data"       , Schema.types.text },
      { "created_at" , Schema.types.time },
      { "updated_at" , Schema.types.time },
      [[ FOREIGN KEY ("user_id"    ) REFERENCES "users"     ("id") ON DELETE CASCADE ]],
      [[ FOREIGN KEY ("resource_id") REFERENCES "resources" ("id") ON DELETE CASCADE ]],
    })
    Schema.create_table ("aliases", {
      { "id"         , Schema.types.text { primary_key = true } },
      { "resource_id", foreign           },
      { "created_at" , Schema.types.time },
      { "updated_at" , Schema.types.time },
      [[ FOREIGN KEY ("resource_id") REFERENCES "resources" ("id") ON DELETE CASCADE ]],
    })
  end,
  function ()
    Schema.create_table ("executions", {
      { "id"           , identifier        },
      { "resource_id"  , foreign           },
      { "image"        , Schema.types.text },
      { "path"         , Schema.types.text { null = true } },
      { "name"         , Schema.types.text { null = true } },
      { "description"  , Schema.types.text { null = true } },
      { "service_id"   , foreign_null      },
      { "created_at"   , Schema.types.time },
      { "updated_at"   , Schema.types.time },
      [[ FOREIGN KEY ("resource_id") REFERENCES "resources" ("id") ON DELETE CASCADE  ]],
      [[ FOREIGN KEY ("service_id" ) REFERENCES "services"  ("id") ON DELETE SET NULL ]],
    })
  end,
}
