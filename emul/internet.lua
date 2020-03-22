-- only for testing
local m = {}
local https = require("ssl.https")

function m.request(url)
  body, code = https.request(url)
  local done = false
  return function() if not done then done = true return body; end end
end

return m