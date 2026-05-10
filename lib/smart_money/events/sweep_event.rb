module SmartMoney
  module Events
    # Emitted when a candle pierces a known liquidity level and rejects.
    # Sweep is the "liquidity grab" signal; reclaim invalidates it.
    class SweepEvent < BaseEvent
      VELOCITIES = %i[normal aggressive].freeze

      attr_reader :side, :swept_level, :wick_extension, :rejection_close,
                  :displacement_atr, :velocity, :candle_index, :reclaimed

      def initialize(timestamp:, side:, swept_level:, wick_extension:, rejection_close:,
                     displacement_atr:, velocity:, candle_index:, reclaimed: false, timeframe: nil)
        @side             = side
        @swept_level      = swept_level
        @wick_extension   = wick_extension
        @rejection_close  = rejection_close
        @displacement_atr = displacement_atr
        @velocity         = velocity
        @candle_index     = candle_index
        @reclaimed        = reclaimed
        super(timestamp: timestamp, timeframe: timeframe)
      end

      def buy_side?
        @side == :buy_side
      end

      def sell_side?
        @side == :sell_side
      end

      def aggressive?
        @velocity == :aggressive
      end

      def reclaimed?
        @reclaimed
      end
    end
  end
end
