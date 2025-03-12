local kong = kong
local cjson = require("cjson.safe")
local http = require("resty.http")

local MyPlugin = {
  VERSION  = "1.0.0",
  PRIORITY = 900,
}

local function dump_conf(conf)
  local t = {}
  for k, v in pairs(conf) do
    local vtype = type(v)
    if vtype == "table" then
      -- optionally recurse or just mark it as [table]
      t[k] = "[table]"
    elseif vtype == "function" or vtype == "userdata" or vtype == "thread" then
      t[k] = "[" .. vtype .. "]"
    else
      t[k] = v
    end
  end
  return cjson.encode(t)
end

function MyPlugin.access(conf)
  kong.log.info("===== Incoming request received by Kong =====")
  kong.log.info("Request Method: ", kong.request.get_method())
  kong.log.info("Request Path: ", kong.request.get_path())
  kong.log.info("Filtered plugin config: ", dump_conf(conf))
  
  -- 1) Log all request headers
  local headers = kong.request.get_headers()
  for k, v in pairs(headers) do
    kong.log.info("Request Header: ", k, " = ", v)
  end

  -- 2) Read the request body (form-encoded)
  local body, err = kong.request.get_body()
  if err then
    kong.log.err("Failed to parse request body: ", err)
    return kong.response.exit(400, { message = "Cannot parse body" })
  end

  kong.log.info("Request Body: ", cjson.encode(body))

  -- 3) Extract required OIDC fields (authorization code, etc.)
  local code         = body["code"]
  local client_id    = body["client_id"]    or conf.client_id
  local client_secret= body["client_secret"]or conf.client_secret
  local redirect_uri = body["redirect_uri"] or conf.redirect_uri
  local grant_type   = body["grant_type"]   or "authorization_code"

  if not code then
    return kong.response.exit(400, { message = "Missing code in request body" })
  end

  kong.log.info("Extracted code: ", code)

  -- 4) Construct the token request
  local token_url = conf.discovery:gsub("/.well%-known/openid%-configuration", "/protocol/openid-connect/token")
  kong.log.info("Forwarding request to Keycloak token endpoint: ", token_url)

  local httpc = http.new()
  local res, request_err = httpc:request_uri(token_url, {
    method  = "POST",
    body    = ngx.encode_args({
      grant_type    = grant_type,
      code          = code,
      client_id     = client_id,
      client_secret = client_secret,
      redirect_uri  = redirect_uri,
    }),
    headers = {
      ["Content-Type"] = "application/x-www-form-urlencoded",
    },
    ssl_verify = false,  -- If you want to skip TLS verification in dev
  })

  -- 5) Handle request failures
  if not res then
    kong.log.err("Failed to call token endpoint: ", request_err)
    return kong.response.exit(502, { message = "Failed to reach token endpoint" })
  end

  -- 6) If Keycloak returns an error, forward that to the client
  if res.status ~= 200 then
    kong.log.err("Keycloak returned non-200 status: ", res.status, " body: ", res.body)
    return kong.response.exit(res.status, cjson.decode(res.body))
  end

  -- 7) Everything is okay; log and return the token JSON
  kong.log.info("Token exchange success. Forwarding token response.")
  local token_response = cjson.decode(res.body)

  -- (Optional) If you wanted to set headers and continue to some upstream, do it here
  -- e.g., kong.service.request.set_header("Authorization", "Bearer " .. token_response.access_token)

  -- Instead, we’ll just return the token JSON to the caller
  return kong.response.exit(200, token_response)
end

return MyPlugin
