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
      { "id"        , Schema.types.serial  { primary_key = true } },
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
      { "id"                  , Schema.types.serial { primary_key = true } },
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
      { "user_id"   , Schema.types.serial },
      { "project_id", Schema.types.serial },
      { "created_at", Schema.types.time   },
      { "updated_at", Schema.types.time   },
      [[ PRIMARY KEY ("id", "user_id", "project_id") ]],
      [[ FOREIGN KEY ("user_id"   ) REFERENCES "users"    ("id") ON DELETE CASCADE ]],
      [[ FOREIGN KEY ("project_id") REFERENCES "projects" ("id") ON DELETE CASCADE ]],
    })
    Schema.create_table ("stars", {
      { "user_id"   , Schema.types.serial },
      { "project_id", Schema.types.serial },
      { "created_at", Schema.types.time   },
      { "updated_at", Schema.types.time   },
      [[ PRIMARY KEY ("user_id", "project_id") ]],
      [[ FOREIGN KEY ("user_id"   ) REFERENCES "users"    ("id") ON DELETE CASCADE ]],
      [[ FOREIGN KEY ("project_id") REFERENCES "projects" ("id") ON DELETE CASCADE ]],
    })
  end,
  function ()
    Schema.create_table ("permissions", {
      { "identity_id", Schema.types.serial  },
      { "project_id" , Schema.types.serial  },
      { "permission" , [[ permission NOT NULL ]] },
      { "created_at" , Schema.types.time    },
      { "updated_at" , Schema.types.time    },
      [[ PRIMARY KEY ("identity_id", "project_id") ]],
      [[ FOREIGN KEY ("project_id" ) REFERENCES "projects"   ("id") ON DELETE CASCADE ]],
      [[ FOREIGN KEY ("identity_id") REFERENCES "identities" ("id") ON DELETE CASCADE ]],
    })
  end,
  function ()
    Schema.create_table ("resources", {
      { "id"         , Schema.types.serial { primary_key = true } },
      { "project_id" , Schema.types.serial },
      { "name"       , Schema.types.text { null = true } },
      { "description", Schema.types.text { null = true } },
      { "data"       , Schema.types.text   },
      { "created_at" , Schema.types.time   },
      { "updated_at" , Schema.types.time   },
      [[ FOREIGN KEY ("project_id") REFERENCES "projects" ("id") ON DELETE CASCADE ]],
    })
    Schema.create_table ("history", {
      { "id"         , Schema.types.serial },
      { "user_id"    , Schema.types.serial },
      { "resource_id", Schema.types.serial },
      { "data"       , Schema.types.text   },
      { "created_at" , Schema.types.time   },
      { "updated_at" , Schema.types.time   },
      [[ PRIMARY KEY ("id", "resource_id") ]],
      [[ FOREIGN KEY ("user_id"    ) REFERENCES "users"     ("id") ON DELETE CASCADE ]],
      [[ FOREIGN KEY ("resource_id") REFERENCES "resources" ("id") ON DELETE CASCADE ]],
    })
    Schema.create_table ("executions", {
      { "id"         , Schema.types.serial  { primary_key = true  } },
      { "user_id"    , Schema.types.serial  },
      { "resource_id", Schema.types.serial  },
      { "name"       , Schema.types.text    { null        = true  } },
      { "description", Schema.types.text    { null        = true  } },
      { "running"    , Schema.types.boolean { default     = false } },
      { "canceled"   , Schema.types.boolean { default     = false } },
      { "created_at" , Schema.types.time    },
      { "updated_at" , Schema.types.time    },
      [[ FOREIGN KEY ("user_id"    ) REFERENCES "users"     ("id") ON DELETE CASCADE ]],
      [[ FOREIGN KEY ("resource_id") REFERENCES "resources" ("id") ON DELETE CASCADE ]],
    })
  end,
}
