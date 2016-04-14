local Model  = require "lapis.db.model".Model
local result = {}

result.identities = Model:extend ("identities", {
  ...
})

result.users = Model:extend ("users", {
  primary_key = "id",
  relations   = {
    { "projects",
      has_many = "projects",
      where = { deleted = false },
    },
  },
})

result.projects = Model:extend ("projects", {
  primary_key = "id",
  relations   = {
    { "user", belongs_to = "users" },
  },
})

result.resources = Model:extend "resources"

result.tags = Model:extend "tags"

return result
