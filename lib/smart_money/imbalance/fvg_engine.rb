module SmartMoney
  module Imbalance
    # Detects 3-candle Fair Value Gaps and tracks their fill lifecycle.
    #
    # Pattern (bullish):  candle[i-2].high  <  candle[i].low
    #   → gap = (candle[i-2].high, candle[i].low)
    # Pattern (bearish):  candle[i-2].low   >  candle[i].high
    #   → gap = (candle[i].high, candle[i-2].low)
    #
    # Emits:
    #   - FvgDetectedEvent      when a gap is created
    #   - FvgPartiallyFilledEvent when price reaches into the gap but does not traverse it
    #   - FvgMitigatedEvent     when price closes beyond the far edge of the gap
    #
    # Memory pruning: mitigated FVGs are removed after PRUNE_AFTER_MITIGATED candles.
    class FvgEngine
      PRUNE_AFTER_MITIGATED = 50

      def initialize
        @subscribers       = []
        @recent            = []
        @active_fvgs       = []
        @mitigated_at      = {}
        @candle_index      = 0
      end

      def subscribe(&block)
        @subscribers << block
      end

      def process(candle)
        @candle_index += 1
        update_active_fvgs(candle)
        @recent << candle
        @recent.shift while @recent.size > 3
        detect_new_fvg if @recent.size == 3
        prune_mitigated_fvgs
      end

      private

      def detect_new_fvg
        c0, _c1, c2 = @recent
        return detect_bullish_fvg(c0, c2) if c0.high < c2.low
        return detect_bearish_fvg(c0, c2) if c0.low  > c2.high
      end

      def detect_bullish_fvg(c0, c2)
        register(direction: :bullish, lower: c0.high, upper: c2.low,
                 origin_candle: @recent[1])
      end

      def detect_bearish_fvg(c0, c2)
        register(direction: :bearish, lower: c2.high, upper: c0.low,
                 origin_candle: @recent[1])
      end

      def register(direction:, lower:, upper:, origin_candle:)
        fvg = Fvg.new(
          direction:     direction,
          lower:         lower,
          upper:         upper,
          origin_index:  @candle_index - 1,
          origin_candle: origin_candle,
          timestamp:     origin_candle.timestamp
        )
        @active_fvgs << fvg
        publish(Events::FvgDetectedEvent.new(
          timestamp:     fvg.timestamp,
          direction:     fvg.direction,
          upper:         fvg.upper,
          lower:         fvg.lower,
          origin_index:  fvg.origin_index,
          origin_candle: fvg.origin_candle
        ))
      end

      def update_active_fvgs(candle)
        @active_fvgs.each do |fvg|
          next unless fvg.open? || fvg.partial?

          transition_state(fvg, candle)
        end
      end

      def transition_state(fvg, candle)
        if mitigated_by?(fvg, candle)
          fvg.state = :mitigated
          emit_mitigated(fvg, candle)
        elsif fvg.open? && touched_by?(fvg, candle)
          fvg.state = :partial
          emit_partial(fvg, candle)
        end
      end

      def touched_by?(fvg, candle)
        candle.high >= fvg.lower && candle.low <= fvg.upper
      end

      def mitigated_by?(fvg, candle)
        fvg.bullish? ? candle.close < fvg.lower : candle.close > fvg.upper
      end

      def emit_partial(fvg, candle)
        publish(Events::FvgPartiallyFilledEvent.new(
          timestamp:     candle.timestamp,
          direction:     fvg.direction,
          upper:         fvg.upper,
          lower:         fvg.lower,
          origin_index:  fvg.origin_index,
          origin_candle: fvg.origin_candle
        ))
      end

      def emit_mitigated(fvg, candle)
        @mitigated_at[fvg.object_id] = @candle_index
        publish(Events::FvgMitigatedEvent.new(
          timestamp:     candle.timestamp,
          direction:     fvg.direction,
          upper:         fvg.upper,
          lower:         fvg.lower,
          origin_index:  fvg.origin_index,
          origin_candle: fvg.origin_candle
        ))
      end

      def prune_mitigated_fvgs
        @active_fvgs.reject! do |fvg|
          mitigated_at = @mitigated_at[fvg.object_id]
          mitigated_at && (@candle_index - mitigated_at) > PRUNE_AFTER_MITIGATED
        end
      end

      def publish(event)
        @subscribers.each { |s| s.call(event) }
      end
    end
  end
end
