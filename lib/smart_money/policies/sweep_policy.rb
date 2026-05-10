module SmartMoney
  module Policies
    # Determines whether a candle constitutes a valid liquidity sweep.
    #
    # A sweep requires:
    #   1. The candle wick pierces the pool level by at least pierce_threshold
    #   2. The candle body (close) rejects back on the opposite side of the level
    #
    # Additionally classifies velocity:
    #   :aggressive — rejection distance >= aggressive_atr * ATR
    #   :normal     — everything else
    class SweepPolicy
      Result = Data.define(:sweeps, :velocity) do
        def sweeps?    = sweeps
        def aggressive? = velocity == :aggressive
      end

      PIERCE_FACTOR    = 0.05
      MIN_PIERCE       = 0.02
      AGGRESSIVE_ATR   = 1.5

      def initialize(pierce_factor: PIERCE_FACTOR,
                     min_pierce: MIN_PIERCE,
                     aggressive_atr: AGGRESSIVE_ATR)
        @pierce_factor  = pierce_factor
        @min_pierce     = min_pierce
        @aggressive_atr = aggressive_atr
      end

      def check_buy_side(candle:, level:, atr:)
        threshold = pierce_threshold(atr)
        return no_sweep unless candle.high > level + threshold
        return no_sweep unless candle.close < level

        rejection  = level - candle.close
        velocity   = rejection >= atr * @aggressive_atr ? :aggressive : :normal
        Result.new(sweeps: true, velocity: velocity)
      end

      def check_sell_side(candle:, level:, atr:)
        threshold = pierce_threshold(atr)
        return no_sweep unless candle.low < level - threshold
        return no_sweep unless candle.close > level

        rejection  = candle.close - level
        velocity   = rejection >= atr * @aggressive_atr ? :aggressive : :normal
        Result.new(sweeps: true, velocity: velocity)
      end

      private

      def pierce_threshold(atr)
        [@min_pierce, atr * @pierce_factor].max
      end

      def no_sweep
        Result.new(sweeps: false, velocity: :normal)
      end
    end
  end
end
