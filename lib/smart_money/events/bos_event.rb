module SmartMoney
  module Events
    class BosEvent < BaseEvent
      attr_reader :direction, :broken_level, :close_price, :displacement_atr, :candle_index

      # direction: :bullish (broke above swing high) or :bearish (broke below swing low)
      def initialize(timestamp:, direction:, broken_level:, close_price:, displacement_atr:, candle_index:, timeframe: nil)
        @direction       = direction
        @broken_level    = broken_level
        @close_price     = close_price
        @displacement_atr = displacement_atr
        @candle_index    = candle_index
        super(timestamp: timestamp, timeframe: timeframe)
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
