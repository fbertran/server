package = "nginx-jwt"
version = "master-1"
source  = {
  url = "git://github.com/auth0/nginx-jwt.git"
}

description = {
  summary    = "Nginx JWT authentication",
  detailed   = [[]],
  homepage   = "https://github.com/auth0/nginx-jwt",
  license    = "MIT/X11",
  maintainer = "Alban Linard <alban@linard.fr>",
}

dependencies = {
  "lua >= 5.1",
  "basexx",
  "lua-cjson",
  "lua-resty-hmac",
}

build = {
  type    = "builtin",
  modules = {
    ["nginx-jwt"] = "nginx-jwt/nginx-jwt.lua",
    ["resty.jwt"] = "nginx-jwt/lib/resty/jwt.lua",
    ["resty.evp"] = "nginx-jwt/lib/resty/evp.lua",
  },
}
