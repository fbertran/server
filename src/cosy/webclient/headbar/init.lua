local Webclient      = require "cosy.webclient"
local I18n           = require "cosy.i18n"
local i18n = I18n.new {
  locale = Webclient.locale,
} + require "cosy.webclient.headbar.i18n"

local HeadBar    = {}
HeadBar.__index  = HeadBar
HeadBar.template = Webclient.request "headbar.html"

local function setmargin ()
  local height = Webclient:jQuery ".navbar-fixed-top":height ()
  Webclient:jQuery ".main-content":css (Webclient.tojs {
    ["margin-top"] = tostring (height + 1) .. "px",
  })
end

function HeadBar.__call ()
  local lock = Webclient.js.new (Webclient.window.Auth0Lock,
    Webclient.info.auth.client_id, Webclient.info.auth.domain)

  Webclient (function ()
    Webclient.show {
      where    = "headbar",
      template = HeadBar.template,
      i18n     = i18n,
      data     = {
        title = Webclient.info.server.hostname,
      },
    }
    setmargin ()
    Webclient:jQuery (Webclient.window):resize (setmargin)
    Webclient:jQuery "#home":click (function ()
      return false
    end)
    Webclient:jQuery "#log-in" :click (function ()
      lock:show (Webclient.tojs {
        popup        = true,
        dict         = Webclient.locale,
        responseType = "token",
        sso          = true,
        authParams   = {
          scope = "openid",
        },
        connections  = {
          "github", "google", "twitter", "facebook",
        },
      }, function (_, _, profile, token) --id_token, access_token, state, refresh_token
        local co = coroutine.create (function ()
          if profile ~= Webclient.js.undefined then
            Webclient:jQuery "#log-in" :hide ()
            Webclient:jQuery "#profile":show ()
            Webclient:jQuery "#log-out":show ()
            Webclient.profile = profile
            Webclient.token   = token
            print (Webclient.api .. "/" .. profile.user_id)
            Webclient.request (Webclient.api .. "/" .. profile.user_id, {
              headers = {
                authorization = token,
              }
            })
          end
        end)
        coroutine.resume (co)
      end)
      return false
    end)
    Webclient:jQuery "#log-out" :click (function ()
      lock.logout (Webclient.tojs {
        ref = Webclient.window.location.href
      })
      Webclient:jQuery "#log-in" :show ()
      Webclient:jQuery "#profile":hide ()
      Webclient:jQuery "#log-out":hide ()
      return false
    end)
    Webclient:jQuery "#log-in" :show ()
    Webclient:jQuery "#profile":hide ()
    Webclient:jQuery "#log-out":hide ()
  end)
end

return setmetatable ({}, HeadBar)
