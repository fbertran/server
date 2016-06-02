local respond_to  = require "lapis.application".respond_to
local Config      = require "lapis.config".get ()
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

  app:match ("/projects/:project/resources/:resource", respond_to {
    HEAD = Decorators.exists {} ..
           Decorators.can_read ..
           function ()
      return { status = 204 }
    end,
    OPTIONS = Decorators.exists {} ..
              Decorators.can_read ..
              function ()
      return { status = 204 }
    end,
    GET = Decorators.exists {} ..
          Decorators.can_read ..
          function (self)
      local edit_url  = Et.render ("ws://edit.<%= host %>:<%= port %>/resources/<%= resource %>", {
        host     = os.getenv "NGINX_HOST", -- or Config.hostname,
        port     = os.getenv "NGINX_PORT", -- or Config.port,
        resource = self.resource.id,
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
    PUT = Decorators.exists {} ..
          Decorators.can_write ..
          function (self)
      self.resource:update {
        name        = self.params.name,
        description = self.params.description,
        history     = self.params.history,
        data        = self.params.data,
      }
      return { status = 204 }
    end,
    PATCH = Decorators.exists {} ..
            Decorators.can_write ..
            function (self)
      self.resource:update {
        name        = self.params.name,
        description = self.params.description,
        history     = self.params.history,
        data        = self.params.data,
      }
      return { status = 204 }
    end,
    DELETE = Decorators.exists {} ..
             Decorators.can_write ..
             function (self)
      self.resource:delete ()
      return { status = 204 }
    end,
    POST = Decorators.exists {} ..
           function ()
      return { status = 405 }
    end,
  })

end
