local Schema   = require "lapis.db.schema"
local Database = require "lapis.db"

return {
  function ()
    Database.query [[
      CREATE TYPE identity AS ENUM ('user', 'project')
    ]]
    Schema.create_table ("identities", {
      { "id"        , Schema.types.serial { primary_key = true } },
      { "identifier", Schema.types.text   { null = true } },
      { "type"      , [[ identity NOT NULL ]] },
    })
  end,
  function ()
    Schema.create_table ("users", {
      { "id"        , Schema.types.foreign_key { primary_key = true } },
      { "path"      , Schema.types.text    { null = true } },
      { "email"     , Schema.types.text    { null = true } },
      { "name"      , Schema.types.text    { null = true } },
      { "picture"   , Schema.types.text    { null = true } },
      { "nickname"  , Schema.types.text    },
      { "reputation", Schema.types.integer },
      { "created_at", Schema.types.time    },
      { "updated_at", Schema.types.time    },
      [[ FOREIGN KEY ("id") REFERENCES "identities" ("id") ON DELETE CASCADE ]],
    })
  end,
  function ()
    Database.query [[
      CREATE TYPE permission AS ENUM ('none', 'read', 'write', 'admin')
    ]]
    Schema.create_table ("projects", {
      { "id"                  , Schema.types.foreign_key { primary_key = true } },
      { "path"                , Schema.types.text   { null = true } },
      { "name"                , Schema.types.text   { null = true } },
      { "description"         , Schema.types.text   { null = true } },
      { "permission_anonymous", [[ permission NOT NULL ]] },
      { "permission_user"     , [[ permission NOT NULL ]] },
      { "created_at"          , Schema.types.time    },
      { "updated_at"          , Schema.types.time    },
      [[ FOREIGN KEY ("id") REFERENCES "identities" ("id") ON DELETE CASCADE ]],
    })
    Schema.create_table ("tags", {
      { "id"        , Schema.types.text   },
      { "user_id"   , Schema.types.foreign_key },
      { "project_id", Schema.types.foreign_key },
      { "created_at", Schema.types.time   },
      { "updated_at", Schema.types.time   },
      [[ PRIMARY KEY ("id", "user_id", "project_id") ]],
      [[ FOREIGN KEY ("user_id"   ) REFERENCES "users"    ("id") ON DELETE CASCADE ]],
      [[ FOREIGN KEY ("project_id") REFERENCES "projects" ("id") ON DELETE CASCADE ]],
    })
    Schema.create_table ("stars", {
      { "user_id"   , Schema.types.foreign_key },
      { "project_id", Schema.types.foreign_key },
      { "created_at", Schema.types.time   },
      { "updated_at", Schema.types.time   },
      [[ PRIMARY KEY ("user_id", "project_id") ]],
      [[ FOREIGN KEY ("user_id"   ) REFERENCES "users"    ("id") ON DELETE CASCADE ]],
      [[ FOREIGN KEY ("project_id") REFERENCES "projects" ("id") ON DELETE CASCADE ]],
    })
  end,
  function ()
    Schema.create_table ("permissions", {
      { "identity_id", Schema.types.foreign_key  },
      { "project_id" , Schema.types.foreign_key  },
      { "permission" , [[ permission NOT NULL ]] },
      { "created_at" , Schema.types.time    },
      { "updated_at" , Schema.types.time    },
      [[ PRIMARY KEY ("identity_id", "project_id") ]],
      [[ FOREIGN KEY ("project_id" ) REFERENCES "projects"   ("id") ON DELETE CASCADE ]],
      [[ FOREIGN KEY ("identity_id") REFERENCES "identities" ("id") ON DELETE CASCADE ]],
    })
  end,
  function ()
    Schema.create_table ("services", {
      { "id"        , Schema.types.serial { primary_key = true } },
      { "path"      , Schema.types.text                 },
      { "docker_url", Schema.types.text { null = true } },
      { "editor_url", Schema.types.text { null = true } },
      { "created_at", Schema.types.time                 },
      { "updated_at", Schema.types.time                 },
    })
  end,
  function ()
    Schema.create_table ("resources", {
      { "id"           , Schema.types.serial { primary_key = true } },
      { "path"         , Schema.types.text   { null = true } },
      { "project_id"   , Schema.types.foreign_key },
      { "name"         , Schema.types.text   { null = true } },
      { "description"  , Schema.types.text   { null = true } },
      { "service_id"   , Schema.types.foreign_key { null = true, default = Database.NULL } },
      { "data"         , Schema.types.text   },
      { "created_at"   , Schema.types.time   },
      { "updated_at"   , Schema.types.time   },
      [[ FOREIGN KEY ("project_id") REFERENCES "projects" ("id") ON DELETE CASCADE  ]],
      [[ FOREIGN KEY ("service_id") REFERENCES "services" ("id") ON DELETE SET NULL ]],
    })
    Schema.create_table ("histories", {
      { "id"         , Schema.types.serial },
      { "path"       , Schema.types.text { null = true } },
      { "user_id"    , Schema.types.foreign_key },
      { "resource_id", Schema.types.foreign_key },
      { "data"       , Schema.types.text   },
      { "created_at" , Schema.types.time   },
      { "updated_at" , Schema.types.time   },
      [[ PRIMARY KEY ("id", "resource_id") ]],
      [[ FOREIGN KEY ("user_id"    ) REFERENCES "users"     ("id") ON DELETE CASCADE ]],
      [[ FOREIGN KEY ("resource_id") REFERENCES "resources" ("id") ON DELETE CASCADE ]],
    })
    Schema.create_table ("aliases", {
      { "id"         , Schema.types.text   { primary_key = true } },
      { "resource_id", Schema.types.foreign_key },
      { "created_at" , Schema.types.time   },
      { "updated_at" , Schema.types.time   },
      [[ FOREIGN KEY ("resource_id") REFERENCES "resources" ("id") ON DELETE CASCADE ]],
    })
  end,
  function ()
    Schema.create_table ("executions", {
      { "id"           , Schema.types.serial { primary_key = true } },
      { "path"         , Schema.types.text   { null = true } },
      { "project_id"   , Schema.types.foreign_key },
      { "resource"     , Schema.types.text   },
      { "image"        , Schema.types.text   },
      { "name"         , Schema.types.text   { null = true } },
      { "description"  , Schema.types.text   { null = true } },
      { "service_id"   , Schema.types.foreign_key { null = true, default = Database.NULL } },
      { "created_at"   , Schema.types.time   },
      { "updated_at"   , Schema.types.time   },
      [[ FOREIGN KEY ("project_id") REFERENCES "projects" ("id") ON DELETE CASCADE  ]],
      [[ FOREIGN KEY ("service_id") REFERENCES "services" ("id") ON DELETE SET NULL ]],
    })
  end,
}
