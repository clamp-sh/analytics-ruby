# frozen_string_literal: true

module Clamp
  module Analytics
    # A typed monetary value attached to any event property.
    #
    #   Clamp::Analytics.track('purchase',
    #     properties: {
    #       plan: 'pro',
    #       total: Clamp::Analytics::Money.new(29.00, 'USD'),
    #       tax: Clamp::Analytics::Money.new(4.35, 'USD')
    #     }
    #   )
    Money = Struct.new(:amount, :currency) do
      def to_wire
        { amount: amount, currency: currency }
      end
    end
  end
end
