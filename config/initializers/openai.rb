OpenAI.configure do |config|
  config.access_token   = ENV["OPENAI_API_KEY"]
  config.request_timeout = 120
end
