local Config     = require "lapis.config".get ()
local respond_to = require "lapis.application".respond_to
local Util       = require "lapis.util"
local Decorators = require "cosy.server.decorators"
local Model      = require "cosy.server.model"
local Http       = require "cosy.server.http"
local Hashid     = require "cosy.server.hashid"
local Token      = require "cosy.server.token"
local Url        = require "socket.url"

return function (app)

  app:match ("/projects/:project", respond_to {
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
      local all_stars = Model.stars:select ("where project_id = ?", self.project.id) or {}
      local stars     = {
        count = #all_stars,
        url   = self.project.url .. "/stars",
      }
      Model.users:include_in (all_stars, "user_id")
      for i, star in ipairs (all_stars) do
        stars [i] = {
          user    = star.user.url,
          project = self.project.url,
        }
      end
      local all_tags = Model.tags:select ("where project_id = ?", self.project.id) or {}
      local tags     = {
        url = self.project.url .. "/tags",
      }
      Model.users:include_in (all_tags, "user_id")
      for i, tag in ipairs (all_tags) do
        tags [i] = {
          id      = tag.id,
          user    = tag.user.url,
          project = self.project.url,
          url     = self.project.url .. "/tags/" .. Util.escape (tag.id),
        }
      end
      local resources = {
        url = self.project.url .. "/resources/",
      }
      for i, resource in ipairs (self.project:get_resources ()) do
        resources [i] = {
          url         = resource.url,
          name        = resource.name,
          description = resource.description,
          docker      = resource.docker_url,
          editor      = resource.editor_url,
        }
      end
      return {
        status = 200,
        json   = {
          id          = Hashid.encode (self.project.id),
          url         = self.project.url,
          name        = self.project.name,
          description = self.project.description,
          resources   = resources,
          stars       = stars,
          tags        = tags,
        },
      }
    end,
    PATCH   = Decorators.exists {}
           .. Decorators.can_write
           .. function (self)
      self.project:update {
        name        = self.params.name,
        description = self.params.description,
      }
      return {
        status = 204,
      }
    end,
    DELETE  = Decorators.exists {}
           .. Decorators.can_admin
           .. function (self)
      local token = Token (self.project.url, {}, math.huge)
      if Config._name ~= "test" then
        for _, resource in ipairs (self.project:get_resources ()) do
          local _, status = Http.json {
            url     = Url.build {
              scheme = "http",
              host   = Config.host,
              port   = Config.port,
              path   = resource.url,
            },
            method  = "DELETE",
            headers = {
              Authorization = "Bearer " .. token,
            },
          }
          assert (status == 204)
        end
        for _, execution in ipairs (self.project:get_executions ()) do
          local _, status = Http.json {
            url     = Url.build {
              scheme = "http",
              host   = Config.host,
              port   = Config.port,
              path   = execution.url,
            },
            method  = "DELETE",
            headers = {
              Authorization = "Bearer " .. token,
            },
          }
          assert (status == 204)
        end
      end
      self.project:get_identity ():delete ()
      return {
        status = 204,
      }
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
