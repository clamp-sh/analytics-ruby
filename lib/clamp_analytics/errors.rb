# frozen_string_literal: true

module Clamp
  module Analytics
    # Base class for all Clamp SDK errors.
    class Error < StandardError; end

    # Raised when track is called before init.
    class NotInitializedError < Error; end

    # Raised when the ingestion API returns a non-2xx response.
    class HTTPError < Error
      attr_reader :status_code, :body

      def initialize(status_code, body)
        @status_code = status_code
        @body = body
        super("clamp_analytics: #{status_code} #{body}")
      end
    end
  end
end
