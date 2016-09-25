local Cjson      = require "cjson"
Cjson.encode_empty_table = function () end -- Fix for Jwt
local Config     = require "lapis.config".get ()
local Database   = require "lapis.db"
local respond_to = require "lapis.application".respond_to
local Decorators = require "cosy.server.decorators"
local Hashid     = require "cosy.server.hashid"
local Http       = require "cosy.server.http"
local Model      = require "cosy.server.model"
local Jwt        = require "jwt"
local Token      = require "cosy.server.token"
local Url        = require "socket.url"

return function (app)

  require "cosy.server.projects.aliases" (app)
  if _G.ngx then
    require "cosy.server.projects.editor"  (app)
  end

  app:match ("/projects/:project/resources/:resource", respond_to {
    HEAD    = Decorators.exists {}
           .. Decorators.can_read
           .. function ()
      return { status = 204 }
    end,
    OPTIONS = Decorators.exists {}
           .. Decorators.can_read
           .. function ()
      return { status = 204 }
    end,
    GET     = Decorators.exists {}
           .. Decorators.can_read
           .. function (self)
      return {
        status = 200,
        json   = {
          id          = Hashid.encode (self.resource.id),
          path        = self.resource.path,
          project     = self.resource:get_project ().path,
          name        = self.resource.name,
          description = self.resource.description,
          docker      = self.resource.docker_url,
          editor      = self.resource.editor_url,
        },
      }
    end,
    PUT     = Decorators.exists {}
           .. Decorators.can_write
           .. function (self)
      self.resource:update {
        name        = self.params.name,
        description = self.params.description,
        history     = self.params.history,
        data        = self.params.data,
      }
      return { status = 204 }
    end,
    PATCH   = Decorators.exists {}
           .. Decorators.can_write
           .. function (self)
      if self.params.patches then
        assert (self.params.data)
        local header = self.req.headers ["COSY_EDITOR"]
        if not header then
          return { status = 403 }
        end
        local token = header:match "Bearer%s+(.+)"
        if not token then
          return { status = 401 }
        end
        local jwt = Jwt.decode (token, {
          keys = {
            public = Config.auth0.client_secret
          }
        })
        if not jwt then
          return { status = 401 }
        end
        local identity = Model.identities:find {
          identifier = jwt.sub
        }
        if not identity
        or identity.type ~= "project"
        or identity.id ~= self.project.id then
          return { status = 401 }
        end
        Database.query [[BEGIN]]
        for _, patch in ipairs (self.params.patches) do
          Model.histories:create {
            user_id     = self.authentified.id,
            resource_id = self.resource.id,
            data        = patch,
          }
        end
        self.resource:update {
          data = self.params.data,
        }
        assert (Database.query [[COMMIT]])
      end
      self.resource:update {
        name        = self.params.name,
        description = self.params.description,
      }
      return { status = 204 }
    end,
    DELETE  = Decorators.exists {}
           .. Decorators.can_write
           .. function (self)
      local token = Token (self.project.path, {}, math.huge)
      pcall (function ()
        local _, status = Http.json {
          method  = "DELETE",
          url     = Url.build {
            scheme = "http",
            host   = "127.0.0.1",
            port   = Config.port,
            path   = self.resource.path .. "/editor",
          },
          headers = {
            Authorization = "Bearer " .. token,
          },
        }
        assert (status == 202)
      end)
      self.resource:delete ()
      return { status = 204 }
    end,
    POST    = Decorators.exists {}
           .. function ()
      return { status = 405 }
    end,
  })

end
