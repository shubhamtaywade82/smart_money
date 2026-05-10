module SmartMoney
  module Policies
    # Encapsulates the three-gate rule for Break of Structure confirmation.
    #
    # Gate 1 — body close: close must cross the level (not just the wick).
    # Gate 2 — displacement: crossing distance must meet the ATR threshold.
    # Gate 3 — structural pivot: the level itself must be a confirmed swing
    #          (enforced by callers who source levels from AdaptiveSwingEngine).
    #
    # Returns a Result value object so callers get both the verdict and the
    # computed displacement in a single call.
    class BosConfirmationPolicy
      Result = Data.define(:confirmed, :displacement) do
        def confirmed? = confirmed
      end

      def initialize(min_displacement_atr: 0.3, require_body_close: true)
        @min_displacement_atr = min_displacement_atr
        @require_body_close   = require_body_close
      end

      def check_bullish(candle:, level:, atr:)
        close = candle.close
        return Result.new(confirmed: false, displacement: 0.0) unless body_close_bullish?(candle, level)

        displacement = close - level
        Result.new(
          confirmed:    displacement >= atr * @min_displacement_atr,
          displacement: displacement
        )
      end

      def check_bearish(candle:, level:, atr:)
        close = candle.close
        return Result.new(confirmed: false, displacement: 0.0) unless body_close_bearish?(candle, level)

        displacement = level - close
        Result.new(
          confirmed:    displacement >= atr * @min_displacement_atr,
          displacement: displacement
        )
      end

      private

      def body_close_bullish?(candle, level)
        @require_body_close ? candle.close > level : candle.high > level
      end

      def body_close_bearish?(candle, level)
        @require_body_close ? candle.close < level : candle.low < level
      end
    end
  end
end
