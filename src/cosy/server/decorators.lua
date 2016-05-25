local Model = require "cosy.server.model"
local Util  = require "lapis.util"

do
  local Function = debug.getmetatable (function () end) or {}
  function Function.__concat (lhs, rhs)
    assert (type (lhs) == "function")
    assert (type (rhs) == "function")
    return lhs (rhs)
  end
  debug.setmetatable (function () end, Function)
end

local Decorators = {}

function Decorators.optional (option)
  return function (f)
    return function (self)
      local result = option (f) (self)
      if type (result) == "table" and result.status ~= 404 then
        return result
      end
      return f (self)
    end
  end
end

function Decorators.is_authentified (f)
  return function (self)
    self.decorators = self.decorators or {}
    if not self.decorators.is_authentified then
      self.decorators.is_authentified = true
      if not self.token then
        return { status = 401 }
      end
      local id = Model.identities:find (self.token.sub)
      if not id then
        return { status = 401 }
      end
      self.authentified = id:get_user ()
    end
    return f (self)
  end
end

function Decorators.optionals (t)
  return function (f)
    return function (self)
      self.decorators = self.decorators or {}
      self.optionals  = self.optionals  or {}
      for _, key in ipairs (t) do
        self.optionals [key] = true
      end
      return f (self)
    end
  end
end

function Decorators.fetch_params (f)
  return function (self)
    self.decorators = self.decorators or {}
    if not self.decorators.fetch_params then
      self.optionals = self.optionals or {}
      self.decorators.fetch_params = true
      if self.params.user then
        local id = Util.unescape (self.params.user)
        if not tonumber (id) then
          return { status = 400 }
        end
        self.user = Model.users:find (id)
        if not self.user and not self.optionals.user then
          return { status = 404 }
        end
      end
      if self.params.project then
        local id = Util.unescape (self.params.project)
        if not tonumber (id) then
          return { status = 400 }
        end
        self.project = Model.projects:find (id)
        if not self.project and not self.optionals.project then
          return { status = 404 }
        end
      end
      if self.params.tag then
        local id = Util.unescape (self.params.tag)
        print ("tag", id, id:match "^[%w%-]+$")
        if not id:match "^[%w%-]+$" then
          return { status = 400 }
        end
        self.tag = Model.tags:find {
          id         = id,
          project_id = self.project and self.project.id,
        }
        if not self.tag and not self.optionals.tag then
          return { status = 404 }
        end
      end
      if self.params.resource then
        local id = Util.unescape (self.params.resource)
        if not tonumber (id) then
          return { status = 400 }
        end
        self.resource = Model.resources:find {
          id         = id,
          project_id = self.project and self.project.id,
        }
        if not self.resource and not self.optionals.resource then
          return { status = 404 }
        end
      end
    end
    return f (self)
  end
end

local function permission (self)
  if self.authentified then
    local p = Model.permissions:find {
      user_id    = self.authentified.id,
      project_id = self.project.id,
    }
    return p and p.permission
        or self.project.permission_user
        or "none"
  else
    return self.project.permission_anonymous
        or "none"
  end
end

function Decorators.can_read (f)
  return Decorators.fetch_params ..
         function (self)
    self.decorators = self.decorators or {}
    if not self.decorators.can_read then
      self.decorators.can_read = true
      local p = permission (self)
      if  p ~= "admin"
      and p ~= "write"
      and p ~= "read" then
        return { status = 403 }
      end
    end
    return f (self)
  end
end

function Decorators.can_write (f)
  return Decorators.fetch_params ..
         Decorators.is_authentified ..
         function (self)
    self.decorators = self.decorators or {}
    if not self.decorators.can_write then
      self.decorators.can_write = true
      local p = permission (self)
      if  p ~= "admin"
      and p ~= "write" then
        return { status = 403 }
      end
    end
    return f (self)
  end
end

function Decorators.can_admin (f)
  return Decorators.fetch_params ..
         Decorators.is_authentified ..
         function (self)
    self.decorators = self.decorators or {}
    if not self.decorators.can_admin then
      self.decorators.can_admin = true
      local p = permission (self)
      if p ~= "admin" then
        print "here"
        return { status = 403 }
      end
    end
    return f (self)
  end
end

return Decorators
