local Config = require "lapis.config".get ()
local Worker = require "resty.qless.worker"

local worker = Worker.new {
  host = Config.redis.host,
  port = Config.redis.port,
  db   = Config.redis.database,
}

worker.middleware = function (job)
  print ("Start worker for job", job.klass)
  coroutine.yield ()
  print ("End worker for job", job.klass)
end

print (pcall (worker.start, worker, {
  interval    = 1,
  concurrency = 4,
  reserver    = "round_robin",
  queues      = { "editors" },
}))
