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
    } + {
      key = {
        fr = "traduction de clef",
      }
    }
    assert.are.equal (i18n.key % {}, "key translation")
  end)

  it ("allows to know if a key exists", function ()
    local I18n = require "cosy.i18n"
    local i18n = I18n.new () + {
      key = {
        en = "key translation",
      }
    }
    assert.is_truthy (i18n / "key")
    assert.is_falsy  (i18n / "clé")
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

  it ("automatically defines plural keys for numbers", function ()
    local I18n = require "cosy.i18n"
    local i18n = I18n.new () + {
      key = {
        en = "{{#n~one}}one{{/n~one}}{{#n~other}}other{{/n~other}}",
      }
    }
    assert.are.equal (i18n.key % {
      n = 2,
    }, "other")
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

  it ("can be applied on tables using the _ key", function ()
    local I18n = require "cosy.i18n"
    local i18n = I18n.new () + {
      key = {
        en = "key translation",
      }
    }
    local result = I18n {
      _ = i18n ["key"],
    }
    assert.are.equal (result.message, "key translation")
  end)

  it ("do not fail when applied on a non-table value", function ()
    local I18n = require "cosy.i18n"
    local result = I18n (true)
    assert.are.equal (result, true)
  end)

end)
