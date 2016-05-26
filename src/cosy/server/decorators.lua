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

function Decorators.exists (except)
  return function (f)
    return function (self)
      for name in pairs (self.params) do
        if not self [name] and not except [name] then
          return { status = 404 }
        end
      end
      return f (self)
    end
  end
end

local function permission (self)
  assert (self.project)
  if self.authentified then
    local p = Model.permissions:find {
      user_id    = self.authentified.id,
      project_id = self.project.id,
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
  return Decorators.is_authentified ..
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
  return Decorators.is_authentified ..
         function (self)
    self.decorators = self.decorators or {}
    if not self.decorators.can_admin then
      self.decorators.can_admin = true
      local p = permission (self)
      if p ~= "admin" then
        return { status = 403 }
      end
    end
    return f (self)
  end
end

return Decorators
