Rails.application.configure do
  # Configure parameters from environment variable or use sensible defaults.
  config.filter_parameters += [:password, :secret, :token, :_key, :auth, :crypt, :salt, :certificate, :ssn, :cvv]
end