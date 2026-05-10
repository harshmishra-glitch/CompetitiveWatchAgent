module Llm
  class OpenaiClient
    class Error           < StandardError; end
    class QuotaExceeded   < Error; end   # 429 + insufficient_quota
    class RateLimited     < Error; end   # 429 transient
    class AuthError       < Error; end   # 401
    class BadRequest      < Error; end   # 4xx
    class ProviderError   < Error; end   # 5xx

    DEFAULT_TEMPERATURE = 0.3
    MAX_RETRIES         = 2

    def self.default
      @default ||= new
    end

    def initialize(client: OpenAI::Client.new)
      @client = client
    end

    def chat(model:, messages:, temperature: DEFAULT_TEMPERATURE,
             json: false, tools: nil, tool_choice: nil, max_tokens: nil)
      params = {
        model:       model,
        messages:    messages,
        temperature: temperature
      }
      params[:max_tokens]      = max_tokens if max_tokens
      params[:response_format] = { type: "json_object" } if json
      params[:tools]           = tools if tools.present?
      params[:tool_choice]     = tool_choice if tool_choice.present?

      response = with_retry { @client.chat(parameters: params) }
      message  = response.dig("choices", 0, "message")
      raise Error, "no message in response: #{response.inspect}" if message.nil?

      if json
        JSON.parse(message["content"].to_s)
      else
        message
      end
    rescue JSON::ParserError => e
      raise Error, "failed to parse JSON output from #{model}: #{e.message}"
    end

    private

    def with_retry
      attempts = 0
      begin
        attempts += 1
        yield
      rescue Faraday::Error, OpenAI::Error => e
        classified = classify(e)
        # Don't retry 4xx (auth, quota, malformed). They won't pass on retry.
        raise classified if classified.is_a?(QuotaExceeded) ||
                            classified.is_a?(AuthError) ||
                            classified.is_a?(BadRequest)
        raise classified if attempts > MAX_RETRIES
        sleep(0.5 * attempts)
        retry
      end
    end

    def classify(error)
      status = extract_status(error)
      body   = extract_body(error)
      code   = body.dig("error", "code") || body.dig("error", "type")
      message = body.dig("error", "message") || error.message

      case status
      when 401 then AuthError.new("OpenAI auth failed: #{message}")
      when 429
        if code.to_s == "insufficient_quota"
          QuotaExceeded.new("OpenAI quota exceeded — check billing: #{message}")
        else
          RateLimited.new("OpenAI rate limit hit: #{message}")
        end
      when 400..499 then BadRequest.new("OpenAI bad request (#{status}): #{message}")
      when 500..599 then ProviderError.new("OpenAI provider error (#{status}): #{message}")
      else                Error.new("OpenAI call failed: #{message}")
      end
    end

    def extract_status(error)
      return error.response_status if error.respond_to?(:response_status) && error.response_status
      msg = error.message.to_s
      m = msg.match(/status (\d{3})/)
      m && m[1].to_i
    end

    def extract_body(error)
      raw = if error.respond_to?(:response_body)
              error.response_body
            elsif error.respond_to?(:response) && error.response.is_a?(Hash)
              error.response[:body]
            end
      return {} if raw.nil?
      return raw if raw.is_a?(Hash)
      JSON.parse(raw.to_s)
    rescue JSON::ParserError
      {}
    end
  end
end
