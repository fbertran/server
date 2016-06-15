local Cjson  = require "cjson"
Cjson.encode_empty_table = function () end -- Fix for Jwt
local Jwt    = require "jwt"
local Config = require "lapis.config".get ()
local Util   = require "lapis.util"
local Model  = require "cosy.server.model"
local auth0  = require "cosy.server.users.auth0"

return function (app)

  local function check_token (self)
    local header = self.req.headers ["Authorization"]
    if not header then
      return nil
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
    self.token = jwt
  end

  local function read_json (self)
    local content_type = self.req.headers ["content-type"]
    if not content_type
    or not string.find (content_type:lower(), "application/json", nil, true) then
      return
    end
    _G.ngx.req.read_body ()
    local body = _G.ngx.req.get_body_data ()
    self.json = body and Util.from_json (body) or nil
  end

  local function authenticate (self)
    if not self.token then
      return
    end
    self.identity = Model.identities:find {
      identifier = self.token.sub
    }
    if self.identity then
      if self.identity.type == "user" then
        self.authentified = assert (self.identity:get_user ())
      elseif self.identity.type == "project" then
        self.authentified = assert (self.identity:get_project ())
      end
    else
      -- automatically create user account
      local info
      if  Config._name == "test"
      and self.token.sub:match "^([%w-_]+)|(.*)$"
      and not self.req.headers ["Force"] then
        info = {
          email    = nil,
          name     = "Test user",
          nickname = "test-user",
          picture  = "http://espace-numerique.fr/1337/wp-content/uploads/2014/10/gros-geek.png",
        }
      else
        local status
        info, status = auth0 ("/users/" .. Util.escape (self.token.sub))
        if status ~= 200 then
          return { status = 401 }
        end
      end
      self.identity = Model.identities:create {
        identifier = self.token.sub,
        type       = "user",
      }
      self.authentified = Model.users:create {
        id       = self.identity.id,
        email    = info.email,
        name     = info.name,
        nickname = info.nickname,
        picture  = info.picture,
      }
    end
  end

  local function fetch_params (self)
    if self.params.user then
      local id = Util.unescape (self.params.user)
      if not tonumber (id) then
        return { status = 400 }
      end
      self.user = Model.users:find {
        id = id
      } or false
    end
    if self.params.project then
      local id = Util.unescape (self.params.project)
      if not tonumber (id) then
        return { status = 400 }
      end
      self.project = Model.projects:find {
        id = id,
      } or false
    end
    if self.params.tag then
      local id = Util.unescape (self.params.tag)
      self.tag = Model.tags:find {
        id         = id,
        user_id    = self.authentication and self.authentication.id or nil,
        project_id = self.project and self.project.id or nil,
      } or false
    end
    if self.params.resource then
      local id = Util.unescape (self.params.resource)
      if not tonumber (id) then
        return { status = 400 }
      end
      self.resource = Model.resources:find {
        id         = id,
        project_id = self.project and self.project.id or nil,
      } or false
    end
  end

  app:before_filter (function (self)
    self.json = {}
    local result = check_token  (self)
                or authenticate (self)
                or read_json    (self)
                or fetch_params (self)
    if result then
      self:write (result)
    end
  end)

end
