module Skylight
  module Probes
    module Mongo
      CAT = "db.mongo.command".freeze

      class Probe
        def install
          ::Mongo::Monitoring::Global.subscribe(::Mongo::Monitoring::COMMAND, Subscriber.new)
        end
      end

      class Subscriber
        include Skylight::Util::Logging

        COMMANDS = %i[insert find count distinct update findandmodify findAndModify delete aggregate].freeze

        COMMAND_NAMES = {
          findandmodify: "findAndModify".freeze
        }.freeze

        def initialize
          @events = {}
        end

        def started(event)
          begin_instrumentation(event)
        end

        def succeeded(event)
          end_instrumentation(event)
        end

        def failed(event)
          end_instrumentation(event)
        end

        # For logging
        def config
          Skylight.config
        end

        private

          def begin_instrumentation(event)
            return unless COMMANDS.include?(event.command_name.to_sym)

            command_name = COMMAND_NAMES[event.command_name] || event.command_name.to_s

            title = "#{event.database_name}.#{command_name}"

            command = event.command

            # Not sure if this will always exist
            # Delete so the description will be less redundant
            if (target = command[event.command_name])
              title << " #{target}"
            end

            payload = {}

            # Ruby Hashes are ordered based on insertion so do the most important ones first

            add_value("key".freeze, command, payload)
            add_bound("query".freeze, command, payload)
            add_bound("filter".freeze, command, payload)
            add_value("sort".freeze, command, payload)

            if command_name == "findAndModify".freeze
              add_bound("update".freeze, command, payload)
            end

            add_value("remove".freeze, command, payload)
            add_value("new".freeze, command, payload)

            if (updates = command["updates".freeze])
              # AFAICT the gem generally just sends one item in the updates array
              update = updates[0]
              update_payload = {}
              add_bound("q".freeze, update, update_payload)
              add_bound("u".freeze, update, update_payload)
              add_value("multi".freeze, update, update_payload)
              add_value("upsert".freeze, update, update_payload)

              payload["updates".freeze] = [update_payload]

              if updates.length > 1
                payload["updates".freeze] << "..."
              end
            end

            if (deletes = command["deletes".freeze])
              # AFAICT the gem generally just sends one item in the updates array
              delete = deletes[0]
              delete_payload = {}
              add_bound("q".freeze, delete, delete_payload)
              add_value("limit".freeze, delete, delete_payload)

              payload["deletes".freeze] = [delete_payload]

              if deletes.length > 1
                payload["deletes".freeze] << "..."
              end
            end

            if (pipeline = command["pipeline".freeze])
              payload["pipeline".freeze] = pipeline.map { |segment| extract_binds(segment) }
            end

            # We're ignoring documents from insert because they could have completely inconsistent
            # format which would make it hard to merge.

            opts = {
              category:    CAT,
              title:       title,
              description: payload.empty? ? nil : payload.to_json,
              meta:        { database: event.database_name },
              internal:    true
            }

            @events[event.operation_id] = Skylight.instrument(opts)
          rescue Exception => e
            error "failed to begin instrumentation for Mongo; msg=%s", e.message
          end

          def end_instrumentation(event)
            if (original_event = @events.delete(event.operation_id))
              meta = {}
              if event.is_a?(::Mongo::Monitoring::Event::CommandFailed)
                meta[:exception] = ["CommandFailed", event.message]
              end
              Skylight.done(original_event, meta)
            end
          rescue Exception => e
            error "failed to end instrumentation for Mongo; msg=%s", e.message
          end

          def add_value(key, command, payload)
            if command.key?(key)
              value = command[key]
              payload[key] = value
            end
          end

          def add_bound(key, command, payload)
            if (value = command[key])
              payload[key] = extract_binds(value)
            end
          end

          def extract_binds(hash)
            ret = {}

            hash.each do |k, v|
              ret[k] = v.is_a?(Hash) ? extract_binds(v) : "?".freeze
            end

            ret
          end
      end
    end

    register(:mongo, "Mongo", "mongo", Mongo::Probe.new)
  end
end
