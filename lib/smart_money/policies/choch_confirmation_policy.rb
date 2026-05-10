module SmartMoney
  module Policies
    # Validates a Change of Character (CHOCH) confirmation.
    #
    # CHOCH is structurally identical to BOS but occurs against the prevailing trend.
    # Delegates to BosConfirmationPolicy and adds the trend-direction guard:
    #   - Bullish CHOCH requires an established bearish trend
    #   - Bearish CHOCH requires an established bullish trend
    class ChochConfirmationPolicy
      Result = Data.define(:confirmed, :displacement) do
        def confirmed? = confirmed
      end

      def initialize(min_displacement_atr: 0.3, require_body_close: true)
        @bos_policy = BosConfirmationPolicy.new(
          min_displacement_atr: min_displacement_atr,
          require_body_close:   require_body_close
        )
      end

      def check_bullish(candle:, level:, atr:, trend_state:)
        return not_confirmed unless trend_state.bearish?

        result = @bos_policy.check_bullish(candle: candle, level: level, atr: atr)
        Result.new(confirmed: result.confirmed?, displacement: result.displacement)
      end

      def check_bearish(candle:, level:, atr:, trend_state:)
        return not_confirmed unless trend_state.bullish?

        result = @bos_policy.check_bearish(candle: candle, level: level, atr: atr)
        Result.new(confirmed: result.confirmed?, displacement: result.displacement)
      end

      private

      def not_confirmed
        Result.new(confirmed: false, displacement: 0.0)
      end
    end
  end
end
