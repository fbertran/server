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

function Decorators.is_authentified (f)
  return function (self)
    if not self.token then
      return {
        status = 401,
      }
    end
    local id = Model.identities:find (self.token.sub)
    if not id then
      return {
        status = 401,
      }
    end
    self.authentified = id:get_user ()
    return f (self)
  end
end

function Decorators.param_is_serial (parameter)
  return function (f)
    return function (self)
      local id = Util.unescape (self.params [parameter])
      if not tonumber (id) then
        return {
          status = 400,
        }
      end
      return f (self)
    end
  end
end

function Decorators.param_is_user (parameter)
  return function (f)
    return function (self)
      local id   = Util.unescape (self.params [parameter])
      local user = Model.identities:find (id)
      if not user then
        return {
          status = 404,
        }
      end
      self.user = user:get_user ()
      return f (self)
    end
  end
end

function Decorators.param_is_project (parameter)
  return function (f)
    return function (self)
      local id = Util.unescape (self.params [parameter])
      if not tonumber (id) then
        return {
          status = 400,
        }
      end
      local project = Model.projects:find (id)
      if not project then
        return {
          status = 404,
        }
      end
      self.project = project
      return f (self)
    end
  end
end

return Decorators
