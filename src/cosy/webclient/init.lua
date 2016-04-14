local Et = require "etlua"
local MT = {}
local Webclient = setmetatable ({
  shown = {},
}, MT)

Webclient.js        = _G.js
Webclient.window    = Webclient.js.global
Webclient.document  = Webclient.js.global.document
Webclient.navigator = Webclient.js.global.navigator
Webclient.locale    = Webclient.js.global.navigator.language
Webclient.origin    = Webclient.js.global.location.origin
Webclient.jQuery    = Webclient.window.jQuery
Webclient.request   = _G.request
Webclient.tojs      = _G.tojs

-- local function replace (t)
--   if type (t) ~= "table" then
--     return t
--   elseif t._ then
--     return t.message
--   else
--     for k, v in pairs (t) do
--       t [k] = replace (v)
--     end
--     return t
--   end
-- end

function MT.__call (_, f, ...)
  local args = { ... }
  xpcall (function ()
    return f (table.unpack (args))
  end, function (err)
    print ("error:", err)
    print (debug.traceback ())
  end)
end

function Webclient.show (component)
  local where     = component.where
  local data      = component.data or {}
  local i18n      = component.i18n
  local template  = component.template
  local container = Webclient:jQuery ("#" .. where)
  data.translate = function (key)
    return i18n [key] % {}
  end
  container:html (Et.render (template, data))
end

function Webclient.log (...)
  Webclient.window.console:log (...)
end

do
  Webclient.api  = Webclient.origin:gsub ("://www", "://api")
  Webclient.info = Webclient.window.JSON:parse (_G.request (Webclient.api))
  Webclient.log (Webclient.info)
end

return Webclient
