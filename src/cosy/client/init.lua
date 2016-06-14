local Client = {}

function Client.new (options)
  local result = setmetatable ({
    server  = options.server,
    token   = options.token,
    request = options.request,
  }, Client)
  local status = result.request (result.server, {
    method  = "GET",
    headers = {
      Authorization = result.token and "Bearer " .. result.token,
    },
  })
  assert (status == 200, status)
  return result
end

return Client
