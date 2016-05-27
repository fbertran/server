local Config     = require "lapis.config".get ()
local Util       = require "lapis.util"
local Model      = require "cosy.server.model"
local auth0      = require "cosy.server.users.auth0"

return function (app)

  local function read_json (self)
    local content_type = self.req.headers ["content-type"]
    if not content_type
    or not string.find (content_type:lower(), "application/json", nil, true) then
      return
    end
    _G.ngx.req.read_body ()
    self.json = Util.from_json (_G.ngx.req.get_body_data ())
  end

  local function authenticate (self)
    if not self.token then
      return
    end
    local id = Model.identities:find {
      id = self.token.sub
    }
    if id then
      self.authentified = id:get_user ()
    else -- automatically create account
      local info
      if Config._name == "test" and not self.req.headers ["Force"] then
        info = {
          email    = nil,
          name     = "Alban Linard",
          nickname = "saucisson",
          picture  = "https://avatars.githubusercontent.com/u/1818862?v=3",
        }
      else
        local status
        info, status = auth0 ("/users/" .. Util.escape (self.token.sub))
        if status ~= 200 then
          return { status = 500 }
        end
      end
      self.authentified = Model.users:create {
        email    = info.email,
        name     = info.name,
        nickname = info.nickname,
        picture  = info.picture,
      }
      Model.identities:create {
        id      = self.token.sub,
        user_id = self.authentified.id,
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
    local result = authenticate (self)
                or read_json    (self)
                or fetch_params (self)
    if result then
      self:write (result)
    end
  end)

end
