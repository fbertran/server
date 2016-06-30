local Model  = require "lapis.db.model".Model
local result = {}

result.identities = Model:extend ("identities", {
  relations = {
    { "user",
      has_one = "users",
      key     = "id",
    },
    { "project",
      has_one = "projects",
      key     = "id",
    },
  },
})

result.users = Model:extend ("users", {
  timestamp   = true,
  relations   = {
    { "identity",
      belongs_to = "identities",
      key        = "id",
    },
    { "executions",
      has_many = "executions",
    },
    { "identities",
      has_many = "identities",
    },
  },
})

result.projects = Model:extend ("projects", {
  timestamp   = true,
  relations   = {
    { "identity",
      belongs_to = "identities",
      key        = "id",
    },
    { "permissions",
      has_many = "permissions",
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

result.permissions = Model:extend ("permissions", {
  timestamp   = true,
  primary_key = {
    "identity_id",
    "project_id",
  },
  relations   = {
    { "identity",
      belongs_to = "identities",
    },
    { "project",
      belongs_to = "projects",
    },
  },
})

result.stars = Model:extend ("stars", {
  timestamp   = true,
  primary_key = {
    "user_id",
    "project_id",
  },
  relations   = {
    { "user",
      belongs_to = "users",
    },
    { "project",
      belongs_to = "projects",
    },
  }
})

result.tags = Model:extend ("tags", {
  timestamp   = true,
  primary_key = {
    "id",
    "user_id",
    "project_id",
  },
  relations   = {
    { "user",
      belongs_to = "users",
    },
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
    { "history",
      has_many = "history",
    },
  },
})

result.histories = Model:extend ("histories", {
  timestamp   = true,
  primary_key = {
    "id",
    "resource_id",
  },
  relations   = {
    { "user",
      belongs_to = "users",
    },
    { "resource",
      belongs_to = "resources",
    },
  },
})

result.aliases = Model:extend ("aliases", {
  timestamp   = true,
  relations   = {
    { "resource",
      has_one = "resources",
    },
  },
})

result.executions = Model:extend ("executions", {
  timestamp   = true,
  relations   = {
    { "user",
      belongs_to = "users",
    },
    { "resource",
      belongs_to = "resources",
    },
  },
})

return result
