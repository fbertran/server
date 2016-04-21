local respond_to  = require "lapis.application".respond_to
local json_params = require "lapis.application".json_params
local Config      = require "lapis.config".get ()
local get_redis   = require "lapis.redis".get_redis
local Redis       = require "redis"
local Model       = require "cosy.server.model"
local Decorators  = require "cosy.server.decorators"

return function (app)

  app:match ("/projects/:project/resources", respond_to {
    HEAD = Decorators.param_is_project "project" ..
           function ()
      return { status = 204 }
    end,
    GET = Decorators.param_is_project "project" ..
          function (self)
      local tags = self.project:get_resources () or {}
      return {
        status = 200,
        json   = tags,
      }
    end,
    POST = json_params ..
           Decorators.is_authentified ..
           Decorators.param_is_project "project" ..
           function (self)
      if self.authentified.id ~= self.project.user_id then
        return { status = 403 }
      end
      local resource = Model.resources:create {
        project_id  = self.project.id,
        name        = self.params.name,
        description = self.params.description,
        history     = self.params.history,
        data        = self.params.data,
      }
      return {
        status = 201,
        json   = resource,
      }
    end,
    OPTIONS = Decorators.param_is_project "project" ..
              function ()
      return { status = 204 }
    end,
    DELETE = Decorators.param_is_project "project" ..
             function ()
      return { status = 405 }
    end,
    PATCH = Decorators.param_is_project "project" ..
            function ()
      return { status = 405 }
    end,
    PUT = Decorators.param_is_project "project" ..
          function ()
      return { status = 405 }
    end,
  })

  local script = [[
    local resource = KEYS [1]
    local exists   = redis.call ("get", "resource:" .. resource)
    if exists then
      return true
    else
      redis.call ("set", "resource:" .. resource, "in-progress")
      redis.call ("publish", "resource:edit", resource)
      return false
    end
  ]]

  app:match ("/projects/:project/resources/:resource", respond_to {
    HEAD = Decorators.param_is_project "project" ..
           Decorators.param_is_resource "resource" ..
           function ()
      return { status = 204 }
    end,
    GET = Decorators.param_is_project "project" ..
          Decorators.param_is_resource "resource" ..
          function (self)
      return {
        status = 200,
        json   = self.resource,
      }
    end,
    PUT = json_params ..
          Decorators.is_authentified ..
          Decorators.param_is_project "project" ..
          Decorators.param_is_resource "resource" ..
          function (self)
      if self.authentified.id ~= self.project.user_id then
        return { status = 403 }
      end
      self.resource:update {
        name        = self.params.name,
        description = self.params.description,
        history     = self.params.history,
        data        = self.params.data,
      }
      return { status = 204 }
    end,
    PATCH = json_params ..
            Decorators.is_authentified ..
            Decorators.param_is_project "project" ..
            Decorators.param_is_resource "resource" ..
            function (self)
      if self.authentified.id ~= self.project.user_id then
        return { status = 403 }
      end
      -- FIXME: this code can lead to errors, if the publish takes place
      -- before subscription.
      local redis = get_redis ()
                 or Redis.connect (Config.redis.host, Config.redis.port)
      redis:select (Config.redis.database)
      if not redis:eval (script, 1, self.resource.id) then
        redis:subscribe ("resource:" .. self.resource.id)
        for message in redis.read_reply or redis:pubsub {
            subscribe = { "resource:" .. self.resource.id },
          } do
          if message.kind == "message" then
            break
          end
        end
        redis:unsubscribe ("resource:" .. self.resource.id)
      end
      return {
        status      = 301,
        redirect_to = "ws://edit." .. Config.hostname .. "/" .. self.resource.id,
      }
    end,
    DELETE = Decorators.is_authentified ..
             Decorators.param_is_project "project" ..
             Decorators.param_is_resource "resource" ..
             function (self)
      if self.authentified.id ~= self.project.user_id then
        return { status = 403 }
      end
      self.resource:delete ()
      return { status = 204 }
    end,
    OPTIONS = Decorators.param_is_project "project" ..
              Decorators.param_is_resource "resource" ..
              function ()
      return { status = 204 }
    end,
    POST = Decorators.param_is_project "project" ..
           Decorators.param_is_resource "resource" ..
           function ()
      return { status = 405 }
    end,
  })

end
