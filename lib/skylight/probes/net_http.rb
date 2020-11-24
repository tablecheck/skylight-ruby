require "skylight/formatters/http"

module Skylight
  module Probes
    module NetHTTP
      module Instrumentation
        def request(req, *)
          return super if !started? || Probes::NetHTTP::Probe.disabled?

          method = req.method

          # req['host'] also includes special handling for default ports
          host, port = req["host"] ? req["host"].split(":") : nil

          # If we're connected with a persistent socket
          host ||= address

          path   = req.path
          scheme = use_ssl? ? "https" : "http"

          # Contained in the path
          query = nil

          opts = Formatters::HTTP.build_opts(method, scheme, host, port, path, query)

          Skylight.instrument(opts) { super }
        end
      end

      # Probe for instrumenting Net::HTTP requests. Works by monkeypatching the default Net::HTTP#request method.
      class Probe
        DISABLED_KEY = :__skylight_net_http_disabled

        def self.disable
          state_was = Thread.current[DISABLED_KEY]
          Thread.current[DISABLED_KEY] = true
          yield
        ensure
          Thread.current[DISABLED_KEY] = state_was
        end

        def self.disabled?
          !!Thread.current[DISABLED_KEY]
        end

        def install
          Net::HTTP.prepend(Instrumentation)
        end
      end
    end

    register(:net_http, "Net::HTTP", "net/http", NetHTTP::Probe.new)
  end
end
