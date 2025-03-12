return {
    name = "my-plugin", -- EXACT match
    fields = {
      { config = {
          type = "record",
          fields = {
            { discovery = { type = "string", required = true } },
            { client_id = { type = "string", required = true } },
            { client_secret = { type = "string", required = true } },
            { redirect_uri = { type = "string", required = true } },
          }
      }}
    }
  }
  