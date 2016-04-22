local Config  = require "lapis.config".get ()
local Redis   = require "resty.redis"
local Et      = require "etlua"
local Cjson  = require "cjson"
Cjson.encode_empty_table = function () end -- Fix for Jwt
local Jwt     = require "jwt"
local Time    = require "socket".gettime

return function ()
  local redis  = Redis:new ()
  local ngx     = _G.ngx
  local req     = _G.req

  local ok = redis:connect (Config.redis.host, Config.redis.port)
  if not ok then
    return ngx.exit (500)
  end
  redis:select (Config.redis.database)

  local key = Et.render ("resource:<%= user %>-<%= project %>-<%= resource %>", {
    user     = ngx.var.user,
    project  = ngx.var.project,
    resource = ngx.var.resource,
  })
  local res  = redis:get (key)
  local wait = false

  if res == ngx.null then
    local script = [[
      local key    = KEYS [1]
      local data   = ARGV [1]
      local exists = redis.call ("exists", key)
      if exists == 0 then
        redis.call ("set", key, "...")
        redis.call ("publish", "resource:edit", data)
      end
      return exists
    ]]
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
    local api_url = Et.render ("http://api.<%= host %>:<%= port %>/projects/<%= project %>/resources/<%= resource %>", {
      host     = os.getenv "NGINX_HOST",
      port     = os.getenv "NGINX_PORT",
      project  = ngx.var.project,
      resource = ngx.var.resource,
    })
    local exists = redis:eval (script, 1, key, Cjson.encode {
      user     = ngx.var.user,
      project  = ngx.var.project,
      resource = ngx.var.resource,
      owner    = make_token (ngx.var.user),
      api      = api_url,
    })
    if exists == 0 then
      wait = true
    end
  end

  if res == ngx.null or res == "..." or wait then
    redis:subscribe (key)
    for message in function () return redis:read_reply () end do
      message.kind    = message.kind    or message [1]
      message.channel = message.channel or message [2]
      message.payload = message.payload or message [3]
      if message.kind == "message" then
        redis:unsubscribe (key)
        if message.payload == "" then
          ngx.exit(404)
        end
        break
      end
    end
    res = redis:get (key)
  end

  ngx.var._url = res:gsub ("wss?://", "http://")
  if ngx.ctx.headers then
    for k, v in pairs (ngx.ctx.headers) do
      req.set_header (k, v)
    end
  end
end
