local Model  = require "lapis.db.model".Model
local result = {}

result.user = Model:extend ("users", {
  primary_key = "id",
  relations   = {
    { "projects",
      has_many = "projects",
      where = { deleted = false },
    },
  },
})

result.project = Model:extend ("projects", {
  primary_key = "id",
  relations   = {
    { "user", belongs_to = "users" },
  },
})

result.resource = Model:extend "resources"

result.tag = Model:extend "tags"

return result
