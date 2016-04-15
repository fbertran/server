local environments = {}

environments.server = {
  app     = nil,
  use     = require "lapis.spec".use_test_server,
  request = function (_, ...)
    return require "lapis.spec.server".request (...)
  end,
}

if not os.getenv "Apple_PubSub_Socket_Render" then
  environments.mock = {
    app     = require "cosy.server.app",
    use     = require "lapis.spec".use_test_env,
    request = require "lapis.spec.request".mock_request,
  }
end

return environments
