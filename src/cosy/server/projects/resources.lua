local respond_to  = require "lapis.application".respond_to
local json_params = require "lapis.application".json_params
local Config      = require "lapis.config".get ()
local get_redis   = require "lapis.redis".get_redis
local Util        = require "lapis.util"
local Redis       = require "redis"
local Model       = require "cosy.server.model"
local Decorators  = require "cosy.server.decorators"
local Jwt         = require "jwt"
local Time        = require "socket".gettime
local Et          = require "etlua"

local function make_token (sub, contents)
  local claims = {
    iss = "https://cosyverif.eu.auth0.com",
    sub = sub,
    aud = Config.auth0.client_id,
    exp = Time () + 10 * 3600,
    iat = Time (),
    contents = contents,
  }
  return Jwt.encode (claims, {
    alg = "HS256",
    keys = { private = Config.auth0.client_secret },
  })
end

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
    local data     = ARGV [1]
    local exists   = redis.call ("get", "resource:" .. resource)
    if not exists then
      redis.call ("set", "resource:" .. resource, "false")
      redis.call ("publish", "resource:edit", data)
    end
    return exists
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
      local api_url   = Et.render ("http://api.<%= host %>:<%= port %>/projects/<%= project %>/resources/<%= resource %>", {
        host     = os.getenv "NGINX_HOST", -- or Config.hostname,
        port     = os.getenv "NGINX_PORT", -- or Config.port,
        project  = self.project.id,
        resource = self.resource.id,
      })
      local edit_url  = Et.render ("ws://edit.<%= host %>:<%= port %>/<%= resource %>", {
        host     = os.getenv "NGINX_HOST", -- or Config.hostname,
        port     = os.getenv "NGINX_PORT", -- or Config.port,
        resource = self.resource.id,
      })
      local redis = get_redis ()
                 or Redis.connect (Config.redis.host, Config.redis.port)
      redis:select (Config.redis.database)
      local exists = redis:eval (script, 1, self.resource.id, Util.to_json {
        resource = self.resource.id,
        owner    = make_token (self.project.user_id),
        api      = api_url,
      })
      if exists ~= 1 then
        redis:subscribe ("resource:" .. self.resource.id)
        for message in redis.read_reply
                   and function () return redis:read_reply () end
                    or redis:pubsub {
            subscribe = { "resource:" .. self.resource.id },
          } do
          message.kind    = message.kind    or message [1]
          message.channel = message.channel or message [2]
          message.payload = message.payload or message [3]
          if message.kind == "message" then
            exists = message
            break
          end
        end
        redis:unsubscribe ("resource:" .. self.resource.id)
      end
      local result = {
        editor = edit_url,
        token  = make_token (self.authentified.id, {
          user        = self.authentified.id,
          resource    = self.resource.id,
          permissions = {
            read  = true,
            write = self.authentified.id == self.project.user_id,
          },
        }),
      }
      return exists.payload == ""
         and { status = 404 }
          or { status = 200,
               json   = result,
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
