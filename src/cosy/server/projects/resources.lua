local respond_to  = require "lapis.application".respond_to
local json_params = require "lapis.application".json_params
local Config      = require "lapis.config".get ()
local Util        = require "lapis.util"
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
        history     = self.params.history or Util.to_json {},
        data        = self.params.data    or "",
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

  app:match ("/projects/:project/resources/:resource", respond_to {
    HEAD = Decorators.param_is_project "project" ..
           Decorators.param_is_resource "resource" ..
           function ()
      return { status = 204 }
    end,
    GET = Decorators.param_is_project "project" ..
          Decorators.param_is_resource "resource" ..
          function (self)
      if self.token then
        local id = Model.identities:find (self.token.sub)
        if id then
          self.authentified = id:get_user ()
        end
      end
      local edit_url  = Et.render ("ws://edit.<%= host %>:<%= port %>/<%= resource %>", {
        host     = os.getenv "NGINX_HOST", -- or Config.hostname,
        port     = os.getenv "NGINX_PORT", -- or Config.port,
        resource = Et.render ("<%= user %>-<%= project %>-<%= resource %>", {
          user     = self.project.user_id,
          project  = self.project.id,
          resource = self.resource.id,
        }),
      })
      return {
        status = 200,
        json   = {
          resource = self.resource,
          editor   = self.authentified and edit_url,
          token    = self.authentified and make_token (self.authentified.id, {
            user        = self.authentified.id,
            resource    = self.resource.id,
            permissions = {
              read  = true,
              write = self.authentified.id == self.project.user_id,
            },
          }),
        }
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
      -- FIXME: history should be updatable by part
      self.resource:update {
        name        = self.params.name,
        description = self.params.description,
        history     = self.params.history,
        data        = self.params.data,
      }
      return { status = 204 }
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
