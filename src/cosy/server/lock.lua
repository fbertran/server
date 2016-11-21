if _G.ngx then

  local Redis = require "resty.redis"

  local Lock = {}

  Lock.__index = Lock

  Lock.scripts = {
    lock = {
      script = [[
        local val = redis.call ('setnx', KEYS [1], ARGV [1])
        if val then
          redis.call ('expire', KEYS [1], ARGV [2])
          return 1
        else
          return 0
        end
      ]],
      hash   = nil,
    },
    unlock = {
      script = [[
        local val = redis.call ('get', KEYS [1])
        if not val then
          return 0
        end
        if val == ARGV [1] then
          redis.call ('del', KEYS [1])
          return 1
        else
          return 0
        end
      ]],
      hash   = nil,
    },
  }

  function Lock.new (_, config)
    config = config or {}
    assert (type (config) == "table")
    local lock = setmetatable ({
      host     = config.host     or "127.0.0.1",
      port     = config.port     or 6379,
      database = config.database or 0,
      exptime  = config.exptime  or 30,
      timeout  = config.timeout  or 5,
      step     = config.step     or 0.001,
      ratio    = config.ratio    or 2,
      max_step = config.max_step or 0.5,
      locked   = {},
    }, Lock)
    if lock.step <= 0 then
      lock.step = 0.001
    end
    lock.id    = tostring (lock)
    lock.proxy = newproxy (true)
    getmetatable (lock.proxy).__gc = function() Lock.__gc (lock) end
    lock.redis = Redis:new ()
    local ok, err = lock.redis:connect (lock.host, lock.port)
    if not ok then
      return nil, err
    end
    lock.redis:select (lock.database)
    for _, script in pairs (Lock.scripts) do
      if not script.hash then
        script.hash, err = lock.redis:script ("LOAD", script.script)
      end
      if not script.hash then
        return nil, err
      end
    end
    return lock
  end

  function Lock.lock (lock, key)
    assert (getmetatable (lock) == Lock)
    if lock.locked [key] then
      return nil, "locked"
    end
    local elapsed = 0
    local hash    = Lock.scripts.lock.hash
    if lock.redis:evalsha (hash, 1, key, lock.id, lock.timeout) then
      lock.locked [key] = true
      return elapsed
    end
    -- https://github.com/openresty/lua-resty-lock/blob/master/lib/resty/lock.lua
    local step     = lock.step
    local timeout  = lock.timeout
    while timeout > 0 do
      if step > timeout then
        step = timeout
      end
      _G.ngx.sleep (step)
      elapsed = elapsed + step
      timeout = timeout - step
      if lock.redis:evalsha (hash, 1, key, lock.id, lock.timeout) then
        lock.locked [key] = true
        return elapsed
      end
      if timeout <= 0 then
        break
      end
      step = step * lock.ratio
      if step > lock.max_step then
        step = lock.max_step
      end
    end
    return nil, "timeout"
  end

  function Lock.unlock (lock, key)
    assert (getmetatable (lock) == Lock)
    if not lock.locked [key] then
      return nil, "unlocked"
    end
    local hash = Lock.scripts.unlock.hash
    if lock.redis:evalsha (hash, 1, key, lock.id) then
      lock.locked [key] = nil
      return true
    end
    return nil
  end

  function Lock.__gc (lock)
    assert (getmetatable (lock) == Lock)
    lock.redis:close ()
  end

  return Lock

else

  local Lock = {}

  Lock.__index = Lock

  function Lock.new ()
    return setmetatable ({}, Lock)
  end

  function Lock.lock (lock)
    assert (getmetatable (lock) == Lock)
    return 0
  end

  function Lock.unlock (lock)
    assert (getmetatable (lock) == Lock)
    return true
  end

  return Lock

end
