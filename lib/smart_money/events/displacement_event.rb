module SmartMoney
  module Events
    # Emitted when a candle (or sequence) shows institutional-grade displacement:
    # body size large relative to ATR, optional volume expansion.
    class DisplacementEvent < BaseEvent
      STRENGTHS = %i[weak strong].freeze

      attr_reader :direction, :body_atr, :strength, :score,
                  :candle_count, :origin_candle, :candle_index

      def initialize(timestamp:, direction:, body_atr:, strength:, score:,
                     candle_count:, origin_candle:, candle_index:, timeframe: nil)
        @direction      = direction
        @body_atr       = body_atr
        @strength       = strength
        @score          = score
        @candle_count   = candle_count
        @origin_candle  = origin_candle
        @candle_index   = candle_index
        super(timestamp: timestamp, timeframe: timeframe)
      end

      def bullish?
        @direction == :bullish
      end

      def bearish?
        @direction == :bearish
      end

      def strong?
        @strength == :strong
      end
    end
  end
end
