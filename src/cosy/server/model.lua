local Model  = require "lapis.db.model".Model
local result = {}

result.identities = Model:extend ("identities", {
  relations = {
    {
      "user",
      belongs_to = "users",
    },
  },
})

result.users = Model:extend ("users", {
  timestamp   = true,
  relations   = {
    {
      "projects",
      belongs_to = "projects",
    },
    {
      "identities",
      belongs_to = "identities",
    },
  },
})

result.projects = Model:extend ("projects", {
  timestamp   = true,
  relations   = {
    {
      "permissions",
      has_many = "permissions",
    },
    {
      "resources",
      has_many = "resources",
    },
    {
      "tags",
      has_many = "tags",
    },
    {
      "stars",
      has_many = "stars",
    },
  },
})

result.permissions = Model:extend ("permissions", {
  timestamp   = true,
  primary_key = {
      "user_id",
      "project_id",
  },
  relations   = {
    {
      "user",
      belongs_to = "users",
    },
    {
      "project",
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
    {
      "user",
      belongs_to = "users",
    },
    {
      "project",
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
    {
      "user",
      belongs_to = "users",
    },
    {
      "project",
      belongs_to = "projects",
    },
  },
})

result.resources = Model:extend ("resources", {
  timestamp   = true,
  relations   = {
    {
      "project",
      belongs_to = "projects",
    },
    {
      "history",
      has_many = "history",
    },
  },
})

result.history = Model:extend ("history", {
  timestamp   = true,
  primary_key = {
      "id",
      "resource_id",
  },
  relations   = {
    {
      "user",
      belongs_to = "users",
    },
    {
      "resource",
      has_many = "resources",
    },
  },
})

result.executions = Model:extend ("executions", {
  timestamp   = true,
  relations   = {
    {
      "resource",
      belongs_to = "resources",
    },
  },
})

return result
