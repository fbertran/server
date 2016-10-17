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
      local histories = Model.histories:select ([[ where resource_id = ? order by created_at ]], self.resource.id)
      local history = {}
      for _, h in ipairs (histories) do
        history [#history+1] = {
          id       = Hashid.encode (h.id),
          data     = h.data,
          resource = h:get_resource ().path,
          user     = h:get_user     ().path,
        }
      end
      return {
        status = 200,
        json   = {
          id          = Hashid.encode (self.resource.id),
          path        = self.resource.path,
          project     = self.resource:get_project ().path,
          name        = self.resource.name,
          description = self.resource.description,
          data        = self.resource.data,
          history     = history,
          docker      = self.resource.docker_url,
          editor      = self.resource.editor_url,
        },
      }
    end,
    PATCH   = Decorators.exists {
                patches = true,
                data    = true,
              }
           .. Decorators.can_write
           .. function (self)
      if self.json.patches then
        assert (self.json.data)
        if self.identity.type   ~= "project"
        or self.authentified.id ~= self.project.id then
          return { status = 403 }
        end
        for _, patch in ipairs (self.json.patches) do
          local jwt = Jwt.decode (patch.token, {
            keys = {
              public = Config.auth0.client_secret
            }
          })
          if not jwt then
            return { status = 400 }
          end
          local identity = Model.identities:find {
            identifier = jwt.sub
          }
          if not identity then
            return { status = 400 }
          end
          patch.user_id = identity.id
        end
        Database.query [[BEGIN]]
        for _, patch in ipairs (self.json.patches) do
          Model.histories:create {
            data        = patch.data,
            user_id     = patch.user_id,
            resource_id = self.resource.id,
          }
        end
        self.resource:update {
          data = self.json.data,
        }
        assert (Database.query [[COMMIT]])
      end
      self.resource:update {
        name        = self.json.name,
        description = self.json.description,
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
    PUT     = Decorators.exists {}
           .. function ()
      return { status = 405 }
    end,
    POST    = Decorators.exists {}
           .. function ()
      return { status = 405 }
    end,
  })

end
