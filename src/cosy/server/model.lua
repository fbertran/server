local Model  = require "lapis.db.model".Model
local result = {}

result.identities = Model:extend ("identities", {
  relations = {
    { "user",
      belongs_to = "users",
    },
  },
})

result.users = Model:extend ("users", {
  timestamp   = true,
  relations   = {
    { "projects",
      has_many = "projects",
    },
    { "identities",
      has_many = "identities",
    },
  },
})

result.stars = Model:extend ("stars", {
  timestamp   = true,
  primary_key = { "user_id", "project_id" },
  relations   = {
    { "user",
      belongs_to = "users",
    },
    { "project",
      has_many = "projects",
    },
  }
})

result.projects = Model:extend ("projects", {
  timestamp   = true,
  relations   = {
    { "user",
      belongs_to = "users",
    },
    { "resources",
      has_many = "resources",
    },
    { "tags",
      has_many = "tags",
    },
    { "stars",
      has_many = "stars",
    },
  },
})

result.tags = Model:extend ("tags", {
  timestamp   = true,
  primary_key = { "id", "project_id" },
  relations   = {
    { "project",
      belongs_to = "projects",
    },
  },
})

result.resources = Model:extend ("resources", {
  timestamp   = true,
  relations   = {
    { "project",
      belongs_to = "projects",
    },
  },
})

result.executions = Model:extend ("executions", {
  timestamp   = true,
  relations   = {
    { "resource",
      belongs_to = "resources",
    },
  },
})

return result
