local Cjson   = require "cjson"
Cjson.encode_empty_table = function () end -- Fix for Jwt
local Config  = require "lapis.config".get ()
local Util    = require "lapis.util"
local Model   = require "cosy.server.model"
local Http    = require "cosy.server.http"
local Hashid  = require "cosy.server.hashid"
local Et      = require "etlua"
local Jwt     = require "jwt"

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
    self.token      = token
    self.token_data = jwt
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
      identifier = self.token_data.sub,
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
      and self.token_data.sub:match "^([%w-_]+)|(.*)$"
      and not self.req.headers ["Force"] then
        info = {
          email    = nil,
          name     = "Test user",
          nickname = "test-user",
          picture  = "http://espace-numerique.fr/1337/wp-content/uploads/2014/10/gros-geek.png",
        }
      else
        local status
        info, status = Http.json {
          url      = Config.auth0.domain .. "/api/v2/users/" .. Util.escape (self.token_data.sub),
          headers  = {
            Authorization = "Bearer " .. Config.auth0.api_token,
          },
        }
        if status ~= 200 then
          return { status = 401 }
        end
      end
      self.authentified = Model.users:create {
        path     = "FIXME",
        email    = info.email,
        name     = info.name,
        nickname = info.nickname,
        picture  = info.picture,
      }
      self.authentified:update {
        path = Et.render ("/users/<%- user %>", {
          user = Hashid.encode (self.authentified.id),
        }),
      }
      self.identity = Model.identities:create {
        identifier = self.token_data.sub,
        id         = self.authentified.id,
        type       = "user",
      }
    end
  end

  local function fetch_params (self)
    if self.params.id then
      self.params.id = Hashid.decode (Util.unescape (self.params.id))
      if not tonumber (self.params.id) then
        return { status = 400 }
      end
      self.id = Model.identities:find {
        id = self.params.id,
      } or false
    end
    if self.params.user then
      self.params.user = Hashid.decode (Util.unescape (self.params.user))
      if not tonumber (self.params.user) then
        return { status = 400 }
      end
      self.user = Model.users:find {
        id = self.params.user,
      } or false
    end
    if self.params.project then
      self.params.project = Hashid.decode (Util.unescape (self.params.project))
      if not tonumber (self.params.project) then
        return { status = 400 }
      end
      self.project = Model.projects:find {
        id = self.params.project,
      } or false
    end
    if self.params.tag then
      self.params.tag = Util.unescape (self.params.tag)
      self.tag = Model.tags:find {
        id         = self.params.tag,
        project_id = self.project and self.project.id or nil,
      } or false
    end
    if self.params.resource then
      self.params.resource = Hashid.decode (Util.unescape (self.params.resource))
      if not tonumber (self.params.resource) then
        return { status = 400 }
      end
      self.resource = Model.resources:find {
        id         = self.params.resource,
        project_id = self.project and self.project.id or nil,
      } or false
    end
    if self.params.execution then
      self.params.execution = Hashid.decode (Util.unescape (self.params.execution))
      if not tonumber (self.params.execution) then
        return { status = 400 }
      end
      self.execution = Model.executions:find {
        id          = self.params.execution,
        resource_id = self.resource and self.resource.id or nil,
      } or false
    end
    if self.params.alias then
      self.params.alias = Util.unescape (self.params.alias)
      self.alias = Model.aliases:find {
        id = self.params.alias,
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
