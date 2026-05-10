module SmartMoney
  module Policies
    # Validates whether a candle constitutes an institutional displacement move.
    #
    # Gates:
    #   1. Body size >= min_body_atr * ATR
    #   2. Volume expanded vs trailing average (optional; controlled by require_volume)
    class DisplacementPolicy
      Result = Data.define(:qualifies, :direction, :body_atr, :strength) do
        def qualifies?  = qualifies
        def strong?     = strength == :strong
      end

      MIN_BODY_ATR            = 0.8
      VOLUME_EXPANSION_FACTOR = 1.3

      def initialize(min_body_atr: MIN_BODY_ATR,
                     volume_expansion_factor: VOLUME_EXPANSION_FACTOR,
                     require_volume: false)
        @min_body_atr            = min_body_atr
        @volume_expansion_factor = volume_expansion_factor
        @require_volume          = require_volume
      end

      def check(candle:, atr:, volume_baseline: nil)
        body_atr = candle.body_size / atr
        return no_displacement unless body_atr >= @min_body_atr

        direction = candle.bullish? ? :bullish : :bearish
        strength  = resolve_strength(candle, volume_baseline)
        return no_displacement if @require_volume && strength == :weak

        Result.new(qualifies: true, direction: direction,
                   body_atr: body_atr.round(2), strength: strength)
      end

      private

      def resolve_strength(candle, volume_baseline)
        return :strong if volume_baseline.nil? || volume_baseline <= 0

        candle.volume >= volume_baseline * @volume_expansion_factor ? :strong : :weak
      end

      def no_displacement
        Result.new(qualifies: false, direction: nil, body_atr: 0.0, strength: :weak)
      end
    end
  end
end
