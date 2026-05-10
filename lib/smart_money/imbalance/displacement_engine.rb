module SmartMoney
  module Imbalance
    # Detects displacement: institutional-grade body expansion.
    #
    # Signals:
    #   - body size >= MIN_BODY_ATR multiples of current ATR
    #   - direction matches body color
    #   - strength is :strong with volume expansion vs trailing average, else :weak
    #   - consecutive same-direction displacements are tracked and scored cumulatively
    #
    # Emits a DisplacementEvent on every qualifying candle. Sequence-aware:
    #   `candle_count` and `score` reflect the running streak; `origin_candle`
    #   is the first candle of the streak.
    class DisplacementEngine
      MIN_BODY_ATR            = 0.8
      VOLUME_EXPANSION_FACTOR = 1.3
      VOLUME_WINDOW           = 20

      def initialize
        @subscribers   = []
        @volume_window = []
        @streak        = []
        @candle_index  = 0
      end

      def subscribe(&block)
        @subscribers << block
      end

      def process(candle, atr)
        @candle_index += 1
        update_volume_window(candle.volume)
        return unless atr&.positive?

        evaluate(candle, atr)
      end

      private

      def evaluate(candle, atr)
        body_atr = candle.body_size / atr
        return reset_streak if body_atr < MIN_BODY_ATR

        direction = candle.bullish? ? :bullish : :bearish
        reset_streak unless streak_continues?(direction)
        extend_streak(candle, direction, body_atr)
        emit(candle, direction, body_atr)
      end

      def streak_continues?(direction)
        @streak.empty? || @streak.first[:direction] == direction
      end

      def extend_streak(candle, direction, body_atr)
        @streak << { candle: candle, direction: direction, body_atr: body_atr }
      end

      def emit(candle, direction, body_atr)
        publish(Events::DisplacementEvent.new(
          timestamp:     candle.timestamp,
          direction:     direction,
          body_atr:      body_atr.round(2),
          strength:      strength_for(candle),
          score:         streak_score,
          candle_count:  @streak.size,
          origin_candle: @streak.first[:candle],
          candle_index:  @candle_index
        ))
      end

      def streak_score
        @streak.sum { |s| s[:body_atr] }.round(2)
      end

      def strength_for(candle)
        volume_expanded?(candle) ? :strong : :weak
      end

      def volume_expanded?(candle)
        prior = @volume_window[0..-2]
        return true if prior.size < 2

        baseline = prior.sum / prior.size.to_f
        return true if baseline <= 0

        candle.volume >= baseline * VOLUME_EXPANSION_FACTOR
      end

      def update_volume_window(volume)
        @volume_window << volume
        @volume_window.shift if @volume_window.size > VOLUME_WINDOW
      end

      def reset_streak
        @streak = []
      end

      def publish(event)
        @subscribers.each { |s| s.call(event) }
      end
    end
  end
end
