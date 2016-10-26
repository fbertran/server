local Cjson      = require "cjson"
Cjson.encode_empty_table = function () end -- Fix for Jwt
local Config     = require "lapis.config".get ()
local respond_to = require "lapis.application".respond_to
local Decorators = require "cosy.server.decorators"
local Hashid     = require "cosy.server.hashid"
local Http       = require "cosy.server.http"
local Lock       = require "cosy.server.lock"
local Model      = require "cosy.server.model"
local Jwt        = require "jwt"
local Token      = require "cosy.server.token"
local Url        = require "socket.url"

return function (app)

  require "cosy.server.projects.resources.aliases" (app)
  if _G.ngx then
    require "cosy.server.projects.resources.editor"     (app)
    require "cosy.server.projects.resources.executions" (app)
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
      if self.json.patches or self.json.data then
        if not self.json.data
        or not self.json.editor
        or type (self.json.patches) ~= "table" then
          return { status = 400 }
        end
        local jwt = Jwt.decode (self.json.editor, {
          keys = {
            public = Config.auth0.client_secret
          }
        })
        if not jwt or jwt.sub ~= self.project.path then
          return { status = 403 }
        end
        local lock = Lock:new (Config.redis)
        assert (lock:lock (self.resource.path))
        for _, patch in ipairs (self.json.patches) do
          Model.histories:create {
            data        = patch,
            user_id     = self.authentified.id,
            resource_id = self.resource.id,
          }
        end
        self.resource:update {
          data = self.json.data,
        }
        assert (lock:unlock (self.resource.path))
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
        for _, execution in ipairs (self.resource:get_executions ()) do
          local _, status = Http.json {
            method  = "DELETE",
            url     = Url.build {
              scheme = "http",
              host   = "127.0.0.1",
              port   = Config.port,
              path   = execution.path,
            },
            headers = {
              Authorization = "Bearer " .. token,
            },
          }
          assert (status == 202)
        end
      end)
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
