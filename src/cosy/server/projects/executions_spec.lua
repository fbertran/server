local assert  = require "luassert"
local Mime    = require "mime"
local Et      = require "etlua"
local Hashids = require "hashids"
local Json    = require "cjson"
local Test    = require "cosy.server.test"
local Http    = require "cosy.server.http"

local Config = {
  auth0       = {
    domain        = assert (os.getenv "AUTH0_DOMAIN"),
    client_id     = assert (os.getenv "AUTH0_ID"    ),
    client_secret = assert (os.getenv "AUTH0_SECRET"),
    api_token     = assert (os.getenv "AUTH0_TOKEN" ),
  },
  docker      = {
    username = assert (os.getenv "DOCKER_USER"  ),
    api_key  = assert (os.getenv "DOCKER_SECRET"),
  },
}

local branch
do
  local file = assert (io.popen ("git rev-parse --abbrev-ref HEAD", "r"))
  branch = assert (file:read "*line")
  file:close ()
end

describe ("route /projects/:project/executions/", function ()

  Test.environment.use ()

  local server_url, docker_url
  local headers = {
    ["Authorization"] = "Basic " .. Mime.b64 (Config.docker.username .. ":" .. Config.docker.api_key),
    ["Accept"       ] = "application/json",
    ["Content-type" ] = "application/json",
  }

  setup (function ()
    local url = "https://cloud.docker.com"
    local api = url .. "/api/app/v1"
    -- Create service:
    local id  = branch .. "-" .. Hashids.new (tostring (os.time ())):encode (666)
    local stack, stack_status = Http.json {
      url     = api .. "/stack/",
      method  = "POST",
      headers = headers,
      body    = {
        name     = id,
        services = {
          { name  = "database",
            image = "postgres",
          },
          { name  = "api",
            image = Et.render ("cosyverif/server:<%- branch %>", {
              branch = branch,
            }),
            ports = {
              "8080",
            },
            links = {
              "database",
            },
            environment = {
              RESOLVERS         = "127.0.0.11",
              COSY_PREFIX       = "/usr/local",
              COSY_HOST         = "api:8080",
              COSY_BRANCH       = branch,
              POSTGRES_HOST     = "database",
              POSTGRES_USER     = "postgres",
              POSTGRES_PASSWORD = "",
              POSTGRES_DATABASE = "postgres",
              AUTH0_DOMAIN      = Config.auth0.domain,
              AUTH0_ID          = Config.auth0.client_id,
              AUTH0_SECRET      = Config.auth0.client_secret,
              AUTH0_TOKEN       = Config.auth0.api_token,
              DOCKER_USER       = Config.docker.username,
              DOCKER_SECRET     = Config.docker.api_key,
            },
          },
        },
      },
    }
    assert (stack_status == 201)
    -- Start service:
    local resource = url .. stack.resource_uri
    local _, started_status = Http.json {
      url        = resource .. "start/",
      method     = "POST",
      headers    = headers,
      timeout    = 5, -- seconds
    }
    assert (started_status == 202)
    local services
    do
      local result, status
      while true do
        result, status = Http.json {
          url     = resource,
          method  = "GET",
          headers = headers,
        }
        if status == 200 and result.state:lower () ~= "starting" then
          services = result.services
          break
        else
          os.execute "sleep 1"
        end
      end
      assert (result.state:lower () == "running")
    end
    for _, path in ipairs (services) do
      local service, service_status = Http.json {
        url     = url .. path,
        method  = "GET",
        headers = headers,
      }
      assert (service_status == 200)
      if service.name == "api" then
        local container, container_status = Http.json {
          url     = url .. service.containers [1],
          method  = "GET",
          headers = headers,
        }
        assert (container_status == 200)
        docker_url = resource
        for _, port in ipairs (container.container_ports) do
          local endpoint = port.endpoint_uri
          if endpoint and endpoint ~= Json.null then
            if endpoint:sub (-1) == "/" then
              endpoint = endpoint:sub (1, #endpoint-1)
            end
            server_url = endpoint
            return
          end
        end
      end
    end
    assert (false)
  end)

  teardown (function ()
    while true do
      local _, deleted_status = Http.json {
        url     = docker_url,
        method  = "DELETE",
        headers = headers,
      }
      if deleted_status == 200 or deleted_status == 404 then
        break
      else
        os.execute "sleep 1"
      end
    end
  end)

  local app, project, project_url, resource_url, route, execution, request, naouna

  before_each (function ()
    Test.clean_db ()
    request = Test.environment.request ()
    app     = Test.environment.app ()
  end)

  before_each (function ()
    local token = Test.make_token (Test.identities.naouna)
    local status, result = request (app, "/", {
      method  = "GET",
      headers = { Authorization = "Bearer " .. token },
    })
    assert.are.same (status, 200)
    assert.is.not_nil (result.authentified.id)
    naouna = result.authentified.id
  end)

  before_each (function ()
    local token = Test.make_token (Test.identities.rahan)
    local status, result = request (app, "/projects", {
      method  = "POST",
      headers = {
        Authorization = "Bearer " .. token,
      },
    })
    assert.are.same (status, 201)
    assert.is.not_nil (result.id)
    project = "/projects/" .. result.id
    route    = project .. "/executions/"
  end)

  before_each (function ()
    local token = Test.make_token (Test.identities.rahan)
    local result, status = Http.json {
      url     = server_url .. "/projects/",
      method  = "POST",
      headers = {
        Authorization = "Bearer " .. token,
      },
    }
    assert.are.same (status, 201)
    project_url = server_url .. "/projects/" .. result.id
    result, status = Http.json {
      url     = project_url .. "/resources/",
      method  = "POST",
      headers = {
        Authorization = "Bearer " .. token,
      },
    }
    assert.are.same (status, 201)
    resource_url = project_url .. "/resources/" .. result.id
    local _ = nil
    _, status = Http.json {
      url     = project_url .. "/permissions/user",
      method  = "PUT",
      body    = { permission = "write" },
      headers = { ["Authorization"] = "Bearer " .. token },
    }
    assert.are.same (status, 202)
    _, status = Http.json {
      url     = project_url .. "/permissions/anonymous",
      method  = "PUT",
      body    = { permission = "write" },
      headers = { ["Authorization"] = "Bearer " .. token },
    }
    assert.are.same (status, 202)
  end)

  after_each (function ()
    local token = Test.make_token (project)
    pcall (request, app, execution, {
      method  = "DELETE",
      headers = { ["Authorization"] = "Bearer " .. token },
    })
  end)

  describe ("accessed as", function ()

    describe ("a non-existing resource", function ()

      before_each (function ()
        local token  = Test.make_token (Test.identities.rahan)
        local status = request (app, project, {
          method  = "DELETE",
          headers = { Authorization = "Bearer " .. token},
        })
        assert.are.same (status, 204)
      end)

      describe ("without authentication", function ()

        for _, method in ipairs { "DELETE", "HEAD", "GET", "OPTIONS", "PATCH", "POST", "PUT" } do
          it ("answers to " .. method, function ()
            local status = request (app, route, {
              method = method,
            })
            assert.are.same (status, 404)
          end)
        end

      end)

      describe ("with valid authentication", function ()

        for _, method in ipairs { "DELETE", "HEAD", "GET", "OPTIONS", "PATCH", "POST", "PUT" } do
          it ("answers to " .. method, function ()
            local token  = Test.make_token (Test.identities.rahan)
            local status = request (app, route, {
              method  = method,
              headers = { Authorization = "Bearer " .. token},
            })
            assert.are.same (status, 404)
          end)
        end

      end)

      describe ("with invalid authentication", function ()

        for _, method in ipairs { "DELETE", "HEAD", "GET", "OPTIONS", "PATCH", "POST", "PUT" } do
          it ("answers to " .. method, function ()
            local token  = Test.make_false_token (Test.identities.rahan)
            local status = request (app, route, {
              method  = method,
              headers = { Authorization = "Bearer " .. token},
            })
            assert.are.same (status, 401)
          end)
        end

      end)

    end)

    describe ("an existing resource", function ()

      describe ("without authentication", function ()

        for _, permission in ipairs { "admin", "write", "read" } do
          describe ("with default " .. permission .. " permission", function ()

            before_each (function ()
              local token  = Test.make_token (Test.identities.rahan)
              local status = request (app, project .. "/permissions/anonymous", {
                method  = "PUT",
                json    = { permission = permission },
                headers = { ["Authorization"] = "Bearer " .. token },
              })
              assert.are.same (status, 202)
            end)

            for _, method in ipairs { "HEAD", "OPTIONS" } do
              it ("answers to " .. method, function ()
                local status = request (app, route, {
                  method = method,
                })
                assert.are.same (status, 204)
              end)
            end

            for _, method in ipairs { "GET" } do
              it ("answers to " .. method, function ()
                local status = request (app, route, {
                  method = method,
                })
                assert.are.same (status, 200)
              end)
            end

            for _, method in ipairs { "POST" } do
              it ("answers to " .. method, function ()
                local status = request (app, route, {
                  method = method,
                  json   = {
                    image    = "cogniteev/echo",
                    resource = resource_url,
                  },
                })
                assert.are.same (status, 401)
              end)
            end

            for _, method in ipairs { "DELETE", "PATCH", "PUT" } do
              it ("answers to " .. method, function ()
                local status = request (app, route, {
                  method = method,
                })
                assert.are.same (status, 405)
              end)
            end

          end)
        end

        describe ("with default none permission", function ()

          before_each (function ()
            local token  = Test.make_token (Test.identities.rahan)
            local status = request (app, project .. "/permissions/anonymous", {
              method  = "PUT",
              json    = { permission = "none" },
              headers = { ["Authorization"] = "Bearer " .. token },
            })
            assert.are.same (status, 202)
          end)

          for _, method in ipairs { "HEAD", "GET", "OPTIONS" } do
            it ("answers to " .. method, function ()
              local status = request (app, route, {
                method = method,
              })
              assert.are.same (status, 403)
            end)
          end

          for _, method in ipairs { "POST" } do
            it ("answers to " .. method, function ()
              local status = request (app, route, {
                method = method,
                json   = {
                  image    = "cogniteev/echo",
                  resource = resource_url,
                },
              })
              assert.are.same (status, 401)
            end)
          end

          for _, method in ipairs { "DELETE", "PATCH", "PUT" } do
            it ("answers to " .. method, function ()
              local status = request (app, route, {
                method = method,
              })
              assert.are.same (status, 405)
            end)
          end

        end)

      end)

      describe ("with permission and authentication", function ()

        for _, permission in ipairs { "admin", "write" } do
          describe ("with " .. permission .. " authentication", function ()

            before_each (function ()
              local token  = Test.make_token (Test.identities.rahan)
              local status = request (app, project .. "/permissions/" .. naouna, {
                method  = "PUT",
                json    = { permission = permission },
                headers = {["Authorization"] = "Bearer " .. token },
              })
              assert.are.same (status, 201)
            end)

            for _, method in ipairs { "HEAD", "OPTIONS" } do
              it ("answers to " .. method, function ()
                local token  = Test.make_token (Test.identities.naouna)
                local status = request (app, route, {
                  method  = method,
                  headers = { Authorization = "Bearer " .. token},
                })
                assert.are.same (status, 204)
              end)
            end

            for _, method in ipairs { "GET" } do
              it ("answers to " .. method, function ()
                local token  = Test.make_token (Test.identities.naouna)
                local status = request (app, route, {
                  method  = method,
                  headers = { Authorization = "Bearer " .. token},
                })
                assert.are.same (status, 200)
              end)
            end

            for _, method in ipairs { "POST" } do
              it ("answers to " .. method, function ()
                local token = Test.make_token (Test.identities.naouna)
                local status, result = request (app, route, {
                  method  = method,
                  headers = { Authorization = "Bearer " .. token},
                  json    = {
                    image    = "cogniteev/echo",
                    resource = resource_url,
                  },
                })
                assert.are.same (status, 201)
                execution = project .. "/executions/" .. result.id
              end)
            end

            for _, method in ipairs { "DELETE", "PATCH", "PUT" } do
              it ("answers to " .. method, function ()
                local token  = Test.make_token (Test.identities.naouna)
                local status = request (app, route, {
                  method  = method,
                  headers = { Authorization = "Bearer " .. token},
                })
                assert.are.same (status, 405)
              end)
            end

          end)
        end

        for _, permission in ipairs { "read", "none" } do
          describe ("with " .. permission .. " authentication", function ()

            before_each (function ()
              local token  = Test.make_token (Test.identities.rahan)
              local status = request (app, project .. "/permissions/" .. naouna, {
                method  = "PUT",
                json    = { permission = "none" },
                headers = { ["Authorization"] = "Bearer " .. token },
              })
              assert.are.same (status, 201)
            end)

            for _, method in ipairs { "HEAD", "GET", "OPTIONS", "POST" } do
              it ("answers to " .. method, function ()
                local token  = Test.make_token (Test.identities.naouna)
                local status = request (app, route, {
                  method  = method,
                  headers = { Authorization = "Bearer " .. token},
                })
                assert.are.same (status, 403)
              end)
            end

            for _, method in ipairs { "DELETE", "PATCH", "PUT" } do
              it ("answers to " .. method, function ()
                local token  = Test.make_token (Test.identities.naouna)
                local status = request (app, route, {
                  method  = method,
                  headers = { Authorization = "Bearer " .. token},
                })
                assert.are.same (status, 405)
              end)
            end

          end)
        end

      end)

      describe ("with valid authentication", function ()

        for _, permission in ipairs { "admin", "write" } do
          describe ("with default " .. permission .. " permission", function ()

            before_each (function ()
              local token  = Test.make_token (Test.identities.rahan)
              local status = request (app, project .. "/permissions/user", {
                method  = "PUT",
                json    = { permission = permission },
                headers = { ["Authorization"] = "Bearer " .. token },
              })
              assert.are.same (status, 202)
            end)

            for _, method in ipairs { "HEAD", "OPTIONS" } do
              it ("answers to " .. method, function ()
                local token  = Test.make_token (Test.identities.naouna)
                local status = request (app, route, {
                  method  = method,
                  headers = { Authorization = "Bearer " .. token},
                })
                assert.are.same (status, 204)
              end)
            end

            for _, method in ipairs { "GET" } do
              it ("answers to " .. method, function ()
                local token  = Test.make_token (Test.identities.naouna)
                local status = request (app, route, {
                  method  = method,
                  headers = { Authorization = "Bearer " .. token},
                })
                assert.are.same (status, 200)
              end)
            end

            for _, method in ipairs { "POST" } do
              it ("answers to " .. method, function ()
                local token = Test.make_token (Test.identities.naouna)
                local status, result = request (app, route, {
                  method  = method,
                  headers = { Authorization = "Bearer " .. token},
                  json    = {
                    image    = "cogniteev/echo",
                    resource = resource_url,
                  },
                })
                assert.are.same (status, 201)
                execution = project .. "/executions/" .. result.id
              end)
            end

            for _, method in ipairs { "DELETE", "PATCH", "PUT" } do
              it ("answers to " .. method, function ()
                local token  = Test.make_token (Test.identities.naouna)
                local status = request (app, route, {
                  method  = method,
                  headers = { Authorization = "Bearer " .. token},
                })
                assert.are.same (status, 405)
              end)
            end

          end)

        end

        for _, permission in ipairs { "read", "none" } do
          describe ("with default " .. permission .. " permission", function ()

            before_each (function ()
              local token  = Test.make_token (Test.identities.rahan)
              local status = request (app, project .. "/permissions/user", {
                method  = "PUT",
                json    = { permission = "none" },
                headers = { ["Authorization"] = "Bearer " .. token },
              })
              assert.are.same (status, 202)
            end)

            for _, method in ipairs { "HEAD", "GET", "OPTIONS", "POST" } do
              it ("answers to " .. method, function ()
                local token  = Test.make_token (Test.identities.naouna)
                local status = request (app, route, {
                  method  = method,
                  headers = { Authorization = "Bearer " .. token},
                })
                assert.are.same (status, 403)
              end)
            end

            for _, method in ipairs { "DELETE", "PATCH", "PUT" } do
              it ("answers to " .. method, function ()
                local token  = Test.make_token (Test.identities.naouna)
                local status = request (app, route, {
                  method  = method,
                  headers = { Authorization = "Bearer " .. token},
                })
                assert.are.same (status, 405)
              end)
            end

          end)

        end

      end)

      describe ("with invalid authentication", function ()

        for _, method in ipairs { "DELETE", "HEAD", "GET", "OPTIONS", "PATCH", "POST", "PUT" } do
          it ("answers to " .. method, function ()
            local token  = Test.make_false_token (Test.identities.rahan)
            local status = request (app, route, {
              method  = method,
              headers = { Authorization = "Bearer " .. token},
            })
            assert.are.same (status, 401)
          end)
        end

      end)

      describe ("with project authentication", function ()

        for _, method in ipairs { "HEAD", "OPTIONS" } do
          it ("answers to " .. method, function ()
            local token  = Test.make_token (project)
            local status = request (app, route, {
              method  = method,
              headers = { Authorization = "Bearer " .. token},
            })
            assert.are.same (status, 204)
          end)
        end

        for _, method in ipairs { "GET" } do
          it ("answers to " .. method, function ()
            local token  = Test.make_token (project)
            local status = request (app, route, {
              method  = method,
              headers = { Authorization = "Bearer " .. token},
            })
            assert.are.same (status, 200)
          end)
        end

        for _, method in ipairs { "POST" } do
          it ("answers to " .. method, function ()
            local token  = Test.make_token (project)
            local status = request (app, route, {
              method  = method,
              headers = { Authorization = "Bearer " .. token},
              json    = {
                image    = "cogniteev/echo",
                resource = resource_url,
              },
            })
            assert.are.same (status, 401)
          end)
        end

        for _, method in ipairs { "DELETE", "PATCH", "PUT" } do
          it ("answers to " .. method, function ()
            local token  = Test.make_token (project)
            local status = request (app, route, {
              method  = method,
              headers = { Authorization = "Bearer " .. token},
            })
            assert.are.same (status, 405)
          end)
        end

      end)

      describe ("with non existing image", function ()

        for _, method in ipairs { "HEAD", "OPTIONS" } do
          it ("answers to " .. method, function ()
            local token  = Test.make_token (Test.identities.rahan)
            local status = request (app, route, {
              method  = method,
              headers = { Authorization = "Bearer " .. token},
            })
            assert.are.same (status, 204)
          end)
        end

        for _, method in ipairs { "GET" } do
          it ("answers to " .. method, function ()
            local token  = Test.make_token (Test.identities.rahan)
            local status = request (app, route, {
              method  = method,
              headers = { Authorization = "Bearer " .. token},
            })
            assert.are.same (status, 200)
          end)
        end

        for _, method in ipairs { "POST" } do
          it ("answers to " .. method, function ()
            local token  = Test.make_token (Test.identities.rahan)
            local status = request (app, route, {
              method  = method,
              headers = { Authorization = "Bearer " .. token},
              json    = {
                image    = "cosyverif/nothing",
                resource = resource_url,
              },
            })
            assert.are.same (status, 400)
          end)
        end

        for _, method in ipairs { "DELETE", "PATCH", "PUT" } do
          it ("answers to " .. method, function ()
            local token  = Test.make_token (Test.identities.rahan)
            local status = request (app, route, {
              method  = method,
              headers = { Authorization = "Bearer " .. token},
            })
            assert.are.same (status, 405)
          end)
        end

      end)

      describe ("with non existing resource", function ()

        before_each (function ()
          local token = Test.make_token (Test.identities.rahan)
          local _, status = Http.json {
            url     = resource_url,
            method  = "DELETE",
            headers = {
              Authorization = "Bearer " .. token,
            },
          }
          assert.are.same (status, 204)
        end)

        for _, method in ipairs { "HEAD", "OPTIONS" } do
          it ("answers to " .. method, function ()
            local token  = Test.make_token (Test.identities.rahan)
            local status = request (app, route, {
              method  = method,
              headers = { Authorization = "Bearer " .. token},
            })
            assert.are.same (status, 204)
          end)
        end

        for _, method in ipairs { "GET" } do
          it ("answers to " .. method, function ()
            local token  = Test.make_token (Test.identities.rahan)
            local status = request (app, route, {
              method  = method,
              headers = { Authorization = "Bearer " .. token},
            })
            assert.are.same (status, 200)
          end)
        end

        for _, method in ipairs { "POST" } do
          it ("answers to " .. method, function ()
            local token  = Test.make_token (Test.identities.rahan)
            local status = request (app, route, {
              method  = method,
              headers = { Authorization = "Bearer " .. token},
              json    = {
                image    = "cogniteev/echo",
                resource = resource_url,
              },
            })
            assert.are.same (status, 404)
          end)
        end

        for _, method in ipairs { "DELETE", "PATCH", "PUT" } do
          it ("answers to " .. method, function ()
            local token  = Test.make_token (Test.identities.rahan)
            local status = request (app, route, {
              method  = method,
              headers = { Authorization = "Bearer " .. token},
            })
            assert.are.same (status, 405)
          end)
        end

      end)

      describe ("with non readable resource", function ()

        before_each (function ()
          local token = Test.make_token (Test.identities.rahan)
          local _, status = Http.json {
            url     = project_url .. "/permissions/user",
            method  = "PUT",
            body    = { permission = "none" },
            headers = { ["Authorization"] = "Bearer " .. token },
          }
          assert.are.same (status, 202)
        end)

        before_each (function ()
          local token  = Test.make_token (Test.identities.rahan)
          local status = request (app, project .. "/permissions/" .. naouna, {
            method  = "PUT",
            json    = { permission = "admin" },
            headers = { ["Authorization"] = "Bearer " .. token },
          })
          assert.are.same (status, 201)
        end)

        for _, method in ipairs { "HEAD", "OPTIONS" } do
          it ("answers to " .. method, function ()
            local token  = Test.make_token (Test.identities.naouna)
            local status = request (app, route, {
              method  = method,
              headers = { Authorization = "Bearer " .. token},
            })
            assert.are.same (status, 204)
          end)
        end

        for _, method in ipairs { "GET" } do
          it ("answers to " .. method, function ()
            local token  = Test.make_token (Test.identities.naouna)
            local status = request (app, route, {
              method  = method,
              headers = { Authorization = "Bearer " .. token},
            })
            assert.are.same (status, 200)
          end)
        end

        for _, method in ipairs { "POST" } do
          it ("answers to " .. method, function ()
            local token  = Test.make_token (Test.identities.naouna)
            local status = request (app, route, {
              method  = method,
              headers = { Authorization = "Bearer " .. token},
              json    = {
                image    = "cogniteev/echo",
                resource = resource_url,
              },
            })
            assert.are.same (status, 404)
          end)
        end

        for _, method in ipairs { "DELETE", "PATCH", "PUT" } do
          it ("answers to " .. method, function ()
            local token  = Test.make_token (Test.identities.naouna)
            local status = request (app, route, {
              method  = method,
              headers = { Authorization = "Bearer " .. token},
            })
            assert.are.same (status, 405)
          end)
        end

      end)

    end)

  end)

end)
