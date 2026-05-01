# frozen_string_literal: true

require "json"
require "net/http"
require "time"
require "uri"

require_relative "clamp_analytics/version"
require_relative "clamp_analytics/money"
require_relative "clamp_analytics/errors"

# Server-side analytics SDK for Clamp.
#
#   require "clamp_analytics"
#
#   Clamp::Analytics.init(
#     project_id: "proj_xxx",
#     api_key: ENV.fetch("CLAMP_API_KEY")
#   )
#
#   Clamp::Analytics.track("signup", properties: { plan: "pro", method: "email" })
module Clamp
  module Analytics
    DEFAULT_ENDPOINT = "https://api.clamp.sh"

    @config = nil
    @transport = nil
    @mutex = Mutex.new

    class << self
      # Initialize the SDK. Call once at application boot (Rails initializer,
      # Sinatra setup block, etc.).
      def init(project_id:, api_key:, endpoint: nil)
        @mutex.synchronize do
          @config = {
            project_id: project_id,
            api_key: api_key,
            endpoint: endpoint || DEFAULT_ENDPOINT
          }
        end
      end

      # Track a server-side event.
      #
      # @param name [String] event name
      # @param properties [Hash] optional, values may be String, Integer,
      #   Float, true/false, or Money
      # @param anonymous_id [String, nil] optional, links to a browser visitor
      # @param timestamp [Time, String, nil] optional; if omitted, uses Time.now.utc
      # @raise [NotInitializedError] if init has not been called
      # @raise [HTTPError] on non-2xx response
      # @return [true]
      def track(name, properties: {}, anonymous_id: nil, timestamp: nil)
        cfg = @mutex.synchronize { @config }
        raise NotInitializedError, "clamp_analytics: call Clamp::Analytics.init before track" if cfg.nil?

        payload = { p: cfg[:project_id], name: name }
        payload[:anonymousId] = anonymous_id unless anonymous_id.nil?
        payload[:properties] = serialize_properties(properties) unless properties.empty?
        payload[:timestamp] = serialize_timestamp(timestamp)

        response = transport.call(
          "#{cfg[:endpoint]}/e/s",
          { "content-type" => "application/json", "x-clamp-key" => cfg[:api_key] },
          JSON.generate(payload)
        )

        status = response[:status]
        if status < 200 || status >= 300
          raise HTTPError.new(status, response[:body].to_s)
        end

        true
      end

      # Capture an exception as a `$error` event. Convenience wrapper that
      # extracts message/type/backtrace from the exception and forwards to
      # {.track}. The server adds a stable fingerprint at ingest so the same
      # bug groups across occurrences.
      #
      #   begin
      #     process_webhook(payload)
      #   rescue => e
      #     Clamp::Analytics.capture_error(e, context: { webhook: "stripe" })
      #   end
      #
      # @param exception [Exception] the exception to capture
      # @param context [Hash] optional flat hash of additional properties.
      #   Values must be primitives (String, Integer, Float, true/false).
      #   The reserved key `:handled` is ignored if present.
      # @param anonymous_id [String, nil] optional, links to a browser visitor
      # @param timestamp [Time, String, nil] optional
      # @raise [NotInitializedError] if init has not been called
      # @raise [HTTPError] on non-2xx response
      # @return [true]
      def capture_error(exception, context: {}, anonymous_id: nil, timestamp: nil)
        message = (exception.message || "Unknown error")[0, 1024]
        error_type = exception.class.name[0, 64]
        backtrace = (exception.backtrace || []).join("\n")
        stack = backtrace.empty? ? "" : backtrace[0, 16384]

        properties = {
          "error.message" => message,
          "error.type" => error_type,
          "error.stack" => stack,
          "error.handled" => true
        }
        context.each do |k, v|
          key = k.to_s
          next if key == "handled"
          if v.is_a?(String) || v.is_a?(Integer) || v.is_a?(Float) || v == true || v == false
            properties[key] = v
          end
        end

        track("$error", properties: properties, anonymous_id: anonymous_id, timestamp: timestamp)
      end

      # Override the transport. Used by tests; pass nil to restore the default.
      def transport=(transport)
        @mutex.synchronize { @transport = transport }
      end

      # Reset all SDK state. Intended for tests.
      def reset!
        @mutex.synchronize do
          @config = nil
          @transport = nil
        end
      end

      private

      def transport
        @transport || method(:default_transport)
      end

      def default_transport(url, headers, body)
        uri = URI.parse(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == "https")
        http.open_timeout = 5
        http.read_timeout = 10

        request = Net::HTTP::Post.new(uri.request_uri)
        headers.each { |k, v| request[k] = v }
        request.body = body

        response = http.request(request)
        { status: response.code.to_i, body: response.body || "" }
      end

      def serialize_properties(properties)
        properties.each_with_object({}) do |(key, value), out|
          out[key] = case value
                    when Money
                      value.to_wire
                    when String, Integer, Float, TrueClass, FalseClass
                      value
                    else
                      raise ArgumentError,
                            "clamp_analytics: property '#{key}' has unsupported type #{value.class}. " \
                            "Allowed: String, Integer, Float, true/false, Money."
                    end
        end
      end

      def serialize_timestamp(timestamp)
        case timestamp
        when nil
          Time.now.utc.iso8601
        when Time
          timestamp.utc.iso8601
        when String
          timestamp
        else
          raise ArgumentError, "clamp_analytics: timestamp must be Time or String, got #{timestamp.class}"
        end
      end
    end
  end
end
