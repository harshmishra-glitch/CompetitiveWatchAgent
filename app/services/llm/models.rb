module Llm
  module Models
    module_function

    def digest
      ENV.fetch("OPENAI_DIGEST_MODEL", "gpt-4o")
    end

    def chat
      ENV.fetch("OPENAI_CHAT_MODEL", "gpt-4o")
    end

    def threat
      ENV.fetch("OPENAI_THREAT_MODEL", "gpt-4o-mini")
    end
  end
end
