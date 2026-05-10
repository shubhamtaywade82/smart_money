module SmartMoney
  module Events
    # Fair Value Gap lifecycle events.
    # A FVG is a 3-candle imbalance: the middle candle is displacement,
    # the gap is the unfilled range between candle[-2] extreme and candle[0] extreme.
    #
    # Lifecycle:
    #   FvgDetectedEvent     — initial creation
    #   FvgPartiallyFilledEvent — price entered the gap but did not fully traverse it
    #   FvgMitigatedEvent    — price closed beyond the far edge of the gap
    class FvgEvent < BaseEvent
      attr_reader :direction, :upper, :lower, :origin_index, :origin_candle

      def initialize(timestamp:, direction:, upper:, lower:, origin_index:, origin_candle:, timeframe: nil)
        @direction     = direction
        @upper         = upper
        @lower         = lower
        @origin_index  = origin_index
        @origin_candle = origin_candle
        super(timestamp: timestamp, timeframe: timeframe)
      end

      def bullish?
        @direction == :bullish
      end

      def bearish?
        @direction == :bearish
      end

      def partially_filled?
        false
      end

      def mitigated?
        false
      end

      def height
        @upper - @lower
      end
    end

    class FvgDetectedEvent < FvgEvent; end

    class FvgPartiallyFilledEvent < FvgEvent
      def partially_filled?
        true
      end
    end

    class FvgMitigatedEvent < FvgEvent
      def mitigated?
        true
      end
    end
  end
end
