module SmartMoney
  module Events
    class ChochEvent < BaseEvent
      attr_reader :direction, :broken_level, :close_price, :displacement_atr,
                  :candle_index, :prior_trend

      # direction: :bullish (bearish→bullish flip) or :bearish (bullish→bearish flip)
      # prior_trend: the trend being reversed
      def initialize(timestamp:, direction:, broken_level:, close_price:,
                     displacement_atr:, candle_index:, prior_trend:, timeframe: nil)
        @direction        = direction
        @broken_level     = broken_level
        @close_price      = close_price
        @displacement_atr = displacement_atr
        @candle_index     = candle_index
        @prior_trend      = prior_trend
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
