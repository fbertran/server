local Hashids = require "hashids"
local Config  = require "lapis.config".get ()

return {
  encode = function (x)
    local hashid = Hashids.new (Config.hashid.salt, Config.hashid.length)
    return hashid:encode (x)
  end,
  decode = function (x)
    local hashid = Hashids.new (Config.hashid.salt, Config.hashid.length)
    return hashid:decode (x) [1]
  end,
}
