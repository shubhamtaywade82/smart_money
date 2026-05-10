module SmartMoney
  module Structure
    # Detects Break of Structure (BOS) events.
    # Correct BOS requires:
    #   1. Candle body close above/below confirmed swing level (not just wick)
    #   2. Displacement >= min_displacement_atr * ATR
    #   3. The broken swing must be a confirmed structural pivot
    class BosDetector
      def initialize(min_displacement_atr: 0.3, require_body_close: true)
        @min_displacement_atr = min_displacement_atr
        @require_body_close   = require_body_close
        @subscribers          = []
        @broken_highs         = {}
        @broken_lows          = {}
      end

      def subscribe(&block)
        @subscribers << block
      end

      # Process a newly closed candle against the current swing engine state.
      # `swing_engine` provides access to confirmed_highs / confirmed_lows.
      # `atr` is the current ATR value.
      # `candle_index` is the absolute index.
      # Returns a BosEvent or nil.
      def process(candle, swing_engine, atr, candle_index, trend_state)
        return nil unless atr&.positive?

        bullish_bos = check_bullish_bos(candle, swing_engine, atr, candle_index, trend_state)
        bearish_bos = check_bearish_bos(candle, swing_engine, atr, candle_index, trend_state)

        # At most one BOS per candle — bullish takes precedence if both somehow trigger
        bullish_bos || bearish_bos
      end

      private

      def check_bullish_bos(candle, swing_engine, atr, candle_index, trend_state)
        swing = swing_engine.last_confirmed_high
        return nil unless swing
        return nil if @broken_highs[swing.index]

        level = swing.level
        close = candle.close

        confirming_close = @require_body_close ? close > level : candle.high > level
        return nil unless confirming_close

        displacement = (close - level).abs
        return nil unless displacement >= atr * @min_displacement_atr

        @broken_highs[swing.index] = true
        event = Events::BosEvent.new(
          timestamp:        candle.timestamp,
          direction:        :bullish,
          broken_level:     level,
          close_price:      close,
          displacement_atr: (displacement / atr).round(2),
          candle_index:     candle_index
        )
        trend_state.on_bullish_bos(swing)
        emit(event)
        event
      end

      def check_bearish_bos(candle, swing_engine, atr, candle_index, trend_state)
        swing = swing_engine.last_confirmed_low
        return nil unless swing
        return nil if @broken_lows[swing.index]

        level = swing.level
        close = candle.close

        confirming_close = @require_body_close ? close < level : candle.low < level
        return nil unless confirming_close

        displacement = (level - close).abs
        return nil unless displacement >= atr * @min_displacement_atr

        @broken_lows[swing.index] = true
        event = Events::BosEvent.new(
          timestamp:        candle.timestamp,
          direction:        :bearish,
          broken_level:     level,
          close_price:      close,
          displacement_atr: (displacement / atr).round(2),
          candle_index:     candle_index
        )
        trend_state.on_bearish_bos(swing)
        emit(event)
        event
      end

      def emit(event)
        @subscribers.each { |sub| sub.call(event) }
      end
    end
  end
end
