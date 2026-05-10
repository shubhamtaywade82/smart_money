module SmartMoney
  module OrderBlocks
    # Internal mutable Order Block. Lifecycle: :fresh → :mitigated | :invalidated.
    class OrderBlock
      attr_reader :direction, :high, :low, :origin_candle, :origin_index,
                  :displacement_score, :timestamp
      attr_accessor :state

      def initialize(direction:, origin_candle:, origin_index:, displacement_score:)
        @direction          = direction
        @high               = origin_candle.high
        @low                = origin_candle.low
        @origin_candle      = origin_candle
        @origin_index       = origin_index
        @displacement_score = displacement_score
        @timestamp          = origin_candle.timestamp
        @state              = :fresh
      end

      def fresh?
        @state == :fresh
      end

      def mitigated?
        @state == :mitigated
      end

      def invalidated?
        @state == :invalidated
      end

      def bullish?
        @direction == :bullish
      end

      def bearish?
        @direction == :bearish
      end

      def contains?(level)
        level >= @low && level <= @high
      end
    end
  end
end
