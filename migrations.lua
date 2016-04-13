local Schema = require "lapis.db.schema"

return {
  [1] = function ()
    Schema.create_table ("users", {
      { "id", Schema.types.text },
      { "deleted", Schema.types.boolean },
      "PRIMARY KEY (id)",
    })
  end,
  [2] = function ()
    Schema.create_table ("projects", {
      { "id"     , Schema.types.text },
      { "user"   , Schema.types.text },
      { "deleted", Schema.types.boolean },
      [[ PRIMARY KEY ("id", "user") ]],
      [[ FOREIGN KEY ("user") REFERENCES "users" ("id") ON DELETE CASCADE ]],
    })
  end,
}
