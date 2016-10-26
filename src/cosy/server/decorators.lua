local Model = require "cosy.server.model"

do
  local Function = debug.getmetatable (function () end) or {}
  function Function.__concat (lhs, rhs)
    assert (type (lhs) == "function", debug.traceback ())
    assert (type (rhs) == "function", debug.traceback ())
    return lhs (rhs)
  end
  debug.setmetatable (function () end, Function)
end

local Decorators = {}

function Decorators.is_authentified (f)
  return function (self)
    if not self.authentified then
      return { status = 401 }
    end
    return f (self)
  end
end

function Decorators.is_user (f)
  return Decorators.is_authentified ..
         function (self)
    if self.identity.type ~= "user" then
      return { status = 401 }
    end
    return f (self)
  end
end

function Decorators.exists (except)
  return function (f)
    return function (self)
      local missing = {}
      for name in pairs (self.params) do
        if not self [name] and not except [name] then
          missing [#missing+1] = name
        end
      end
      if #missing > 0 then
        return { status = 404, json = missing }
      end
      return f (self)
    end
  end
end

local function permission (self)
  assert (self.project)
  if self.authentified and self.project then
    local p = Model.permissions:find {
      identity_id = self.identity.id,
      project_id  = self.project.id,
    }
    if p then
      return p.permission
    else
      return self.project.permission_user
    end
  else
    return self.project.permission_anonymous
  end
end

function Decorators.can_read (f)
  return function (self)
    local p = permission (self)
    if  p ~= "admin"
    and p ~= "write"
    and p ~= "read" then
      return { status = 403 }
    end
    return f (self)
  end
end

function Decorators.can_write (f)
  return Decorators.is_authentified ..
         function (self)
    local p = permission (self)
    if  p ~= "admin"
    and p ~= "write" then
      return { status = 403 }
    end
    return f (self)
  end
end

function Decorators.can_admin (f)
  return Decorators.is_authentified ..
         function (self)
    local p = permission (self)
    if p ~= "admin" or self.identity.type ~= "user" then
      return { status = 403 }
    end
    return f (self)
  end
end

return Decorators
