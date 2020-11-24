require "json"

module Skylight
  # @api private
  class ConfigError < RuntimeError; end

  class NativeError < StandardError
    @classes = {}

    def self.register(code, name, message)
      if @classes.key?(code)
        raise "Duplicate error class code: #{code}; name=#{name}"
      end

      Skylight.module_eval <<-RUBY, __FILE__, __LINE__ + 1
        class #{name}Error < NativeError            # class SqlLexError < NativeError
          def self.code; #{code}; end               #   def self.code; 4; end
          def self.message; #{message.to_json}; end #   def self.message; "Failed to lex SQL query."; end
        end                                         # end
      RUBY

      klass = Skylight.const_get("#{name}Error")

      @classes[code] = klass
    end

    def self.for_code(code)
      @classes[code] || self
    end

    attr_reader :method_name

    def self.code
      9999
    end

    def self.formatted_code
      format("%<code>04d", code: code)
    end

    def self.message
      "Encountered an unknown internal error"
    end

    def initialize(method_name)
      @method_name = method_name
      super(format("[E%<code>04d] %<message>s [%<meth>s]", code: code, message: self.class.message, meth: method_name))
    end

    def code
      self.class.code
    end

    def formatted_code
      self.class.formatted_code
    end

    # E0002
    # Too many unique descriptions - daemon only

    # E0003
    register(3, "MaximumTraceSpans", "Exceeded maximum number of spans in a trace.")

    # E0004
    register(4, "SqlLex", "Failed to lex SQL query.")

    # E0005
    register(5, "InstrumenterUnrecoverable", "Instrumenter is not running.")

    # E0006
    register(6, "InvalidUtf8", "Invalid UTF-8")
  end
end
