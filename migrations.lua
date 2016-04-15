local Schema = require "lapis.db.schema"

return {
  [1] = function ()
    Schema.create_table ("users", {
      { "id"        , Schema.types.serial  },
      { "deleted"   , Schema.types.boolean },
      { "reputation", Schema.types.integer },
      { "created_at", Schema.types.time    },
      { "updated_at", Schema.types.time    },
      [[ PRIMARY KEY ("id") ]],
    })
    Schema.create_table ("identities", {
      { "id"     , Schema.types.text   },
      { "user_id", Schema.types.serial },
      [[ PRIMARY KEY ("id") ]],
      [[ FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE CASCADE ]],
    })
    Schema.create_table ("projects", {
      { "id"         , Schema.types.serial  },
      { "user_id"    , Schema.types.serial  },
      { "name"       , Schema.types.text    },
      { "description", Schema.types.text    },
      { "deleted"    , Schema.types.boolean },
      { "created_at" , Schema.types.time    },
      { "updated_at" , Schema.types.time    },
      [[ PRIMARY KEY ("id") ]],
      [[ FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE CASCADE ]],
    })
    Schema.create_table ("tags", {
      { "id"        , Schema.types.text   },
      { "project_id", Schema.types.serial },
      { "created_at", Schema.types.time   },
      { "updated_at", Schema.types.time   },
      [[ PRIMARY KEY ("id", "project_id") ]],
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
    Schema.create_table ("resources", {
      { "id"         , Schema.types.serial  },
      { "project_id" , Schema.types.serial  },
      { "name"       , Schema.types.text    },
      { "description", Schema.types.text    },
      { "deleted"    , Schema.types.boolean },
      { "created_at" , Schema.types.time    },
      { "updated_at" , Schema.types.time    },
      [[ PRIMARY KEY ("id") ]],
      [[ FOREIGN KEY ("project_id") REFERENCES "projects" ("id") ON DELETE CASCADE ]],
    })
    Schema.create_table ("executions", {
      { "id"         , Schema.types.serial  },
      { "resource_id", Schema.types.serial  },
      { "name"       , Schema.types.text    },
      { "running"    , Schema.types.boolean },
      { "canceled"   , Schema.types.boolean },
      { "deleted"    , Schema.types.boolean },
      { "created_at" , Schema.types.time    },
      { "updated_at" , Schema.types.time    },
      [[ PRIMARY KEY ("id") ]],
      [[ FOREIGN KEY ("resource_id") REFERENCES "resources" ("id") ON DELETE CASCADE ]],
    })
  end,
}
