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

local branch = assert (os.getenv "COSY_BRANCH" or os.getenv "WERCKER_GIT_BRANCH")
if not branch or branch == "master" then
  local file = assert (io.popen ("git rev-parse --abbrev-ref HEAD", "r"))
  branch = assert (file:read "*line")
  file:close ()
end

Test.environment.use ()

describe ("#resty route /projects/:project/executions/", function ()

  local server_url
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
          { name  = "postgres",
            image = "postgres",
            tags  = { Config.branch },
          },
          { name  = "redis",
            image = "redis:3.0.7",
            tags  = { Config.branch },
          },
          { name  = "api",
            image = Et.render ("cosyverif/server:<%- branch %>", {
              branch = branch,
            }),
            tags  = { Config.branch },
            ports = {
              "8080",
            },
            links = {
              "postgres",
              "redis",
            },
            environment = {
              COSY_PREFIX       = "/usr/local",
              COSY_BRANCH       = branch,
              REDIS_PORT        = "tcp://redis:6379",
              POSTGRES_PORT     = "tcp://postgres:5432",
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
        for _, port in ipairs (container.container_ports) do
          local endpoint = port.endpoint_uri
          if endpoint and endpoint ~= Json.null then
            if endpoint:sub (-1) == "/" then
              endpoint = endpoint:sub (1, #endpoint-1)
            end
            server_url = endpoint
            while true do
              local _, status = Http.json {
                url     = server_url,
                method  = "GET",
              }
              if status == 200 then
                print ("Stack created", server_url)
                return
              else
                os.execute "sleep 1"
              end
            end
          end
        end
      end
    end
    assert (false)
  end)

  local app, request

  setup (function ()
    Test.clean_db ()
    request = Test.environment.request ()
    app     = Test.environment.app ()
  end)

  teardown (function ()
    while true do
      local status, info = request (app, "/", {
        method = "GET",
      })
      assert.are.equal (status, 200)
      print (info.stats.dockers)
      if info.stats.dockers == 0 then
        break
      end
      os.execute [[ sleep 1 ]]
    end
  end)

  local project, project_token, resources, route, naouna

  setup (function ()
    local token = Test.make_token (Test.identities.rahan)
    resources   = {}
    do -- existing resource
      local result, status = Http.json {
        url     = server_url .. "/projects/",
        method  = "POST",
        headers = {
          Authorization = "Bearer " .. token,
        },
      }
      assert.are.same (status, 201)
      local project_url = server_url .. result.path
      local _
      _, status = Http.json {
        url     = project_url .. "/permissions/user",
        method  = "PUT",
        body    = { permission = "read" },
        headers = { ["Authorization"] = "Bearer " .. token },
      }
      assert.are.same (status, 202)
      _, status = Http.json {
        url     = project_url .. "/permissions/anonymous",
        method  = "PUT",
        body    = { permission = "read" },
        headers = { ["Authorization"] = "Bearer " .. token },
      }
      assert.are.same (status, 202)
      result, status = Http.json {
        url     = project_url .. "/resources/",
        method  = "POST",
        headers = {
          Authorization = "Bearer " .. token,
        },
      }
      assert.are.same (status, 201)
      resources.readable = server_url .. result.path
    end
    do -- missing resource
      local result, status = Http.json {
        url     = server_url .. "/projects/",
        method  = "POST",
        headers = {
          Authorization = "Bearer " .. token,
        },
      }
      assert.are.same (status, 201)
      local project_url = server_url .. result.path
      local _
      _, status = Http.json {
        url     = project_url .. "/permissions/user",
        method  = "PUT",
        body    = { permission = "read" },
        headers = { ["Authorization"] = "Bearer " .. token },
      }
      assert.are.same (status, 202)
      _, status = Http.json {
        url     = project_url .. "/permissions/anonymous",
        method  = "PUT",
        body    = { permission = "read" },
        headers = { ["Authorization"] = "Bearer " .. token },
      }
      assert.are.same (status, 202)
      result, status = Http.json {
        url     = project_url .. "/resources/",
        method  = "POST",
        headers = {
          Authorization = "Bearer " .. token,
        },
      }
      assert.are.same (status, 201)
      resources.missing = server_url .. result.path
      _, status = Http.json {
        url     = resources.missing,
        method  = "DELETE",
        headers = {
          Authorization = "Bearer " .. token,
        },
      }
      assert.are.same (status, 204)
    end
    do -- non-readable resource
      local result, status = Http.json {
        url     = server_url .. "/projects/",
        method  = "POST",
        headers = {
          Authorization = "Bearer " .. token,
        },
      }
      assert.are.same (status, 201)
      local project_url = server_url .. result.path
      local _
      _, status = Http.json {
        url     = project_url .. "/permissions/user",
        method  = "PUT",
        body    = { permission = "none" },
        headers = { ["Authorization"] = "Bearer " .. token },
      }
      assert.are.same (status, 202)
      _, status = Http.json {
        url     = project_url .. "/permissions/anonymous",
        method  = "PUT",
        body    = { permission = "none" },
        headers = { ["Authorization"] = "Bearer " .. token },
      }
      assert.are.same (status, 202)
      result, status = Http.json {
        url     = project_url .. "/resources/",
        method  = "POST",
        headers = {
          Authorization = "Bearer " .. token,
        },
      }
      assert.are.same (status, 201)
      resources.hidden = server_url .. result.path
    end
  end)

  before_each (function ()
    local token = Test.make_token (Test.identities.naouna)
    local status, result = request (app, "/", {
      method  = "GET",
      headers = { Authorization = "Bearer " .. token },
    })
    assert.are.same (status, 200)
    naouna = result.authentified.path:match "/users/(.*)"
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
    project       = result.path
    route         = project .. "/executions/"
    project_token = Test.make_token (result.path)
  end)

  local execution

  after_each (function ()
    request (app, execution, {
      method  = "DELETE",
      headers = { ["Authorization"] = "Bearer " .. project_token },
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
                    image    = "sylvainlasnier/echo",
                    resource = resources.readable,
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
                  image    = "sylvainlasnier/echo",
                  resource = resources.readable,
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
                    image    = "sylvainlasnier/echo",
                    resource = resources.readable,
                  },
                })
                assert.are.same (status, 202)
                execution = result.path
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
                local token = Test.make_token (Test.identities.rahan)
                local status, result = request (app, route, {
                  method  = method,
                  headers = { Authorization = "Bearer " .. token},
                  json    = {
                    image    = "sylvainlasnier/echo",
                    resource = resources.readable,
                  },
                })
                assert.are.same (status, 202)
                execution = result.path
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
            local status = request (app, route, {
              method  = method,
              headers = { Authorization = "Bearer " .. project_token},
            })
            assert.are.same (status, 204)
          end)
        end

        for _, method in ipairs { "GET" } do
          it ("answers to " .. method, function ()
            local status = request (app, route, {
              method  = method,
              headers = { Authorization = "Bearer " .. project_token},
            })
            assert.are.same (status, 200)
          end)
        end

        for _, method in ipairs { "POST" } do
          it ("answers to " .. method, function ()
            local status = request (app, route, {
              method  = method,
              headers = { Authorization = "Bearer " .. project_token},
              json    = {
                image    = "sylvainlasnier/echo",
                resource = resources.readable,
              },
            })
            assert.are.same (status, 401)
          end)
        end

        for _, method in ipairs { "DELETE", "PATCH", "PUT" } do
          it ("answers to " .. method, function ()
            local status = request (app, route, {
              method  = method,
              headers = { Authorization = "Bearer " .. project_token},
            })
            assert.are.same (status, 405)
          end)
        end

      end)

      describe ("with non existing image", function ()

        for _, method in ipairs { "POST" } do
          it ("answers to " .. method, function ()
            local token  = Test.make_token (Test.identities.rahan)
            local status = request (app, route, {
              method  = method,
              headers = { Authorization = "Bearer " .. token},
              json    = {
                image    = "cosyverif/nothing",
                resource = resources.readable,
              },
            })
            assert.are.same (status, 400)
          end)
        end

      end)

      describe ("with non existing resource", function ()

        for _, method in ipairs { "POST" } do
          it ("answers to " .. method, function ()
            local token  = Test.make_token (Test.identities.rahan)
            local status = request (app, route, {
              method  = method,
              headers = { Authorization = "Bearer " .. token},
              json    = {
                image    = "sylvainlasnier/echo",
                resource = resources.missing,
              },
            })
            assert.are.same (status, 400)
          end)
        end

      end)

      describe ("with non readable resource", function ()

        before_each (function ()
          local token  = Test.make_token (Test.identities.rahan)
          local status = request (app, project .. "/permissions/" .. naouna, {
            method  = "PUT",
            json    = { permission = "admin" },
            headers = {["Authorization"] = "Bearer " .. token },
          })
          assert.are.same (status, 201)
        end)

        for _, method in ipairs { "POST" } do
          it ("answers to " .. method, function ()
            local token  = Test.make_token (Test.identities.naouna)
            local status = request (app, route, {
              method  = method,
              headers = { Authorization = "Bearer " .. token},
              json    = {
                image    = "sylvainlasnier/echo",
                resource = resources.hidden,
              },
            })
            assert.are.same (status, 400)
          end)
        end

      end)

    end)

  end)

end)
