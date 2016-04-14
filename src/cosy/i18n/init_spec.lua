require "busted.runner" ()

local assert = require "luassert"

describe ("Module cosy.i18n", function ()

  it ("can be loaded", function ()
    assert.has.no.errors (function ()
      require "cosy.i18n"
    end)
  end)

  it ("can be instantiated", function ()
    assert.has.no.errors (function ()
      local I18n = require "cosy.i18n"
      I18n.new ()
    end)
  end)

  it ("can register translations", function ()
    assert.has.no.errors (function ()
      local I18n = require "cosy.i18n"
      local _    = I18n.new () + {
        key = {
          en = "key translation",
        }
      }
    end)
  end)

  it ("can make use of translations", function ()
    local I18n = require "cosy.i18n"
    local i18n = I18n.new () + {
      key = {
        en = "key translation",
      }
    }
    assert.are.equal (i18n.key % {}, "key translation")
  end)

  it ("uses default language if no translation is available", function ()
    local I18n = require "cosy.i18n"
    local i18n = I18n.new () + {
      key = {
        en = "key translation",
      }
    }
    assert.are.equal (i18n.key % {
      locale = "fr_FR",
    }, "key translation")
  end)

  it ("handles tables", function ()
    local I18n = require "cosy.i18n"
    local i18n = I18n.new () + {
      key = {
        en = "key translation",
      }
    }
    local message = {
      data = {
        _ = i18n.key,
      }
    }
    assert.are.same (I18n (message), {
      data = {
        _       = "key",
        message = "key translation",
      },
    })
  end)

end)
