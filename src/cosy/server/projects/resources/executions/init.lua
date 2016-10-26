local Database   = require "lapis.db"
local respond_to = require "lapis.application".respond_to
local Model      = require "cosy.server.model"
local Decorators = require "cosy.server.decorators"
local Http       = require "cosy.server.http"
local Hashid     = require "cosy.server.hashid"
local Job        = require "cosy.server.jobs.execution"
local Et         = require "etlua"

return function (app)

  require "cosy.server.projects.resources.executions.execution" (app)

  app:match ("/projects/:project/resources/:resource/executions(/)", respond_to {
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
      local executions = self.resource:get_executions () or {}
      local result    = {
        path       = self.resource.path .. "/executions/",
        executions = {},
      }
      for i, execution in ipairs (executions) do
        result.executions [i] = {
          path        = execution.path,
          name        = execution.name,
          description = execution.description,
          docker      = execution.docker_url,
        }
      end
      return {
        status = 200,
        json   = result,
      }
    end,
    POST    = Decorators.exists {}
           .. Decorators.can_write
           .. Decorators.is_user
           .. function (self)
      -- check if image exists and is readable:
      local image, variant = self.json.image:match "([^:]+):?(.*)"
      local result, status = Http.json {
        url    = Et.render ("https://auth.docker.io/token?service=registry.docker.io&scope=repository:<%- image %>:pull", {
          image = image,
        }),
        method = "GET",
      }
      if status ~= 200 then
        return {
          status = 400,
          json   = {
            status = status,
            reason = "image",
          },
        }
      end
      local _
      local docker_token = assert (result.token)
      _, status = Http.json ({
        url     = Et.render ("https://registry-1.docker.io/v2/<%- image %>/manifests/<%- variant %>", {
          image   = image,
          variant = variant == "" and "latest" or variant,
        }),
        method  = "GET",
        headers = {
          ["Authorization"] = "Bearer " .. docker_token,
        }
      }, true)
      if status ~= 200 then
        return {
          status = 400,
          json   = {
            status = status,
            reason = "image",
          },
        }
      end
      -- create execution:
      local execution = Model.executions:create {
        resource_id = self.resource.id,
        image       = self.json.image,
        name        = self.json.name,
        description = self.json.description,
        service_id  = Database.NULL,
      }
      execution:update {
        path = Et.render ("/projects/<%- project %>/resources/<%- resource %>/executions/<%- execution %>", {
          project   = Hashid.encode (self.project.id),
          resource  = Hashid.encode (self.resource.id),
          execution = Hashid.encode (execution.id),
        }),
      }
      Job.start (execution)
      return {
        status = 202,
        json   = {
          id   = Hashid.encode (execution.id),
          path = execution.path,
        }
      }
    end,
    DELETE  = Decorators.exists {}
           .. function ()
      return { status = 405 }
    end,
    PATCH   = Decorators.exists {}
           .. function ()
      return { status = 405 }
    end,
    PUT     = Decorators.exists {}
           .. function ()
      return { status = 405 }
    end,
  })

end
