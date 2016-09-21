local Config     = require "lapis.config".get ()
local respond_to = require "lapis.application".respond_to
local Model      = require "cosy.server.model"
local Decorators = require "cosy.server.decorators"
local Http       = require "cosy.server.http"
local Hashid     = require "cosy.server.hashid"
local Start      = require "cosy.server.jobs.execution.start"
local Qless      = require "resty.qless"
local Et         = require "etlua"

return function (app)

  require "cosy.server.projects.execution" (app)

  app:match ("/projects/:project/executions(/)", respond_to {
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
      local executions = self.project:get_executions () or {}
      local result    = {
        path       = self.project.path .. "/executions/",
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
      -- check if resource exists and is readable:
      local _, result, status
      _, status = Http.json {
        url     = self.json.resource,
        method  = "HEAD",
        headers = {
          ["Authorization"] = "Bearer " .. self.token,
        }
      }
      if status ~= 204 then
        return {
          status = 400,
          json   = {
            status = status,
            reason = "resource",
          },
        }
      end
      -- check if image exists and is readable:
      local image, variant = self.json.image:match "([^:]+):?(.*)"
      result, status = Http.json {
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
        project_id  = self.project.id,
        resource    = self.json.resource,
        image       = self.json.image,
        name        = self.json.name,
        description = self.json.description,
      }
      execution:update {
        path = Et.render ("/projects/<%- project %>/executions/<%- execution %>", {
          project   = Hashid.encode (self.project.id),
          execution = Hashid.encode (execution.id),
        }),
      }
      -- FIXME: issue #6
      local qless = Qless.new (Config.redis)
      local start = qless.jobs:get ("start@" .. execution.path)
      if not start then
        Start.create (execution)
      end
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
