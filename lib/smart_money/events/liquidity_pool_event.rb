module SmartMoney
  module Events
    # Emitted when a resting liquidity pool is identified.
    # Fires the moment a level is touched a second time within tolerance.
    class LiquidityPoolEvent < BaseEvent
      attr_reader :side, :level, :touch_count, :first_index, :last_index

      def initialize(timestamp:, side:, level:, touch_count:, first_index:, last_index:, timeframe: nil)
        @side         = side
        @level        = level
        @touch_count  = touch_count
        @first_index  = first_index
        @last_index   = last_index
        super(timestamp: timestamp, timeframe: timeframe)
      end

      def buy_side?
        @side == :buy_side
      end

      def sell_side?
        @side == :sell_side
      end
    end
  end
end
