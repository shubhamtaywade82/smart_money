module SmartMoney
  module Imbalance
    # Internal mutable Fair Value Gap. Lifecycle is :open → :partial → :mitigated.
    class Fvg
      attr_reader :direction, :upper, :lower, :origin_index, :origin_candle, :timestamp
      attr_accessor :state

      def initialize(direction:, upper:, lower:, origin_index:, origin_candle:, timestamp:)
        @direction     = direction
        @upper         = upper
        @lower         = lower
        @origin_index  = origin_index
        @origin_candle = origin_candle
        @timestamp     = timestamp
        @state         = :open
      end

      def open?
        @state == :open
      end

      def partial?
        @state == :partial
      end

      def mitigated?
        @state == :mitigated
      end

      def bullish?
        @direction == :bullish
      end

      def bearish?
        @direction == :bearish
      end
    end
  end
end
