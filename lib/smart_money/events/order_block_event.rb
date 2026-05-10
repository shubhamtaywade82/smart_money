module SmartMoney
  module Events
    # Order Block lifecycle events.
    # Bullish OB: last bearish candle before bullish displacement.
    # Bearish OB: last bullish candle before bearish displacement.
    #
    # Lifecycle:
    #   OrderBlockDetectedEvent     — created when displacement origin is identified
    #   OrderBlockMitigatedEvent    — price returned and tagged the OB zone
    #   OrderBlockInvalidatedEvent  — price closed decisively beyond the OB on the wrong side
    class OrderBlockEvent < BaseEvent
      attr_reader :direction, :high, :low, :origin_candle, :origin_index, :displacement_score

      def initialize(timestamp:, direction:, high:, low:, origin_candle:, origin_index:,
                     displacement_score:, timeframe: nil)
        @direction          = direction
        @high               = high
        @low                = low
        @origin_candle      = origin_candle
        @origin_index       = origin_index
        @displacement_score = displacement_score
        super(timestamp: timestamp, timeframe: timeframe)
      end

      def bullish?
        @direction == :bullish
      end

      def bearish?
        @direction == :bearish
      end

      def mitigated?
        false
      end

      def invalidated?
        false
      end

      def midpoint
        (@high + @low) / 2.0
      end
    end

    class OrderBlockDetectedEvent < OrderBlockEvent; end

    class OrderBlockMitigatedEvent < OrderBlockEvent
      def mitigated?
        true
      end
    end

    class OrderBlockInvalidatedEvent < OrderBlockEvent
      def invalidated?
        true
      end
    end
  end
end
