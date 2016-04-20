local Test = require "cosy.server.test"

describe ("cosyverif api", function ()
  Test.environment.use ()

  local Jwt
  local Config
  local Time
  local request
  local app

  before_each (function ()
    Jwt     = require "jwt"
    Config  = require "lapis.config".get ()
    Time    = require "socket".gettime
    Test.clean_db ()
    request = Test.environment.request ()
    app     = Test.environment.app ()
  end)

  describe ("route '/auth0' (for testing only)", function ()

    it ("answers to GET without Authorization", function ()
      local status = request (app, "/auth0", {
        method = "GET",
      })
      assert.are.same (status, 200)
    end)

    it ("answers to GET with missing Authorization", function ()
      local status = request (app, "/auth0", {
        method  = "GET",
        headers = { Authorization = "Something"},
      })
      assert.are.same (status, 400)
    end)

    it ("answers to GET with ill-formed Authorization", function ()
      local status = request (app, "/auth0", {
        method  = "GET",
        headers = { Authorization = "Bearer 12345"},
      })
      assert.are.same (status, 401)
    end)

    it ("answers to GET with wrong Authorization", function ()
      local claims = {
        iss = "https://cosyverif.eu.auth0.com",
        sub = "github|1818862",
        aud = Config.auth0.client_id,
        exp = Time () + 10 * 3600,
        iat = Time (),
      }
      local token = Jwt.encode (claims, {
        alg  = "HS256",
        keys = { private = Config.auth0.client_id }
      })
      local status = request (app, "/auth0", {
        method  = "POST",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 401)
    end)


    it ("answers to GET with Authorization", function ()
      local token  = Test.make_token (Test.identities.rahan)
      local status = request (app, "/auth0", {
        method  = "GET",
        headers = { Authorization = "Bearer " .. token},
      })
      assert.are.same (status, 200)
    end)

  end)

end)
