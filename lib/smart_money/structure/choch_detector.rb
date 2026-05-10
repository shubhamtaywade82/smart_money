module SmartMoney
  module Structure
    # Detects Change of Character (CHOCH) events.
    # CHOCH is a BOS against the prevailing trend direction.
    # Requires TrendState to be established (not :ranging) before firing.
    class ChochDetector
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

      # Returns a ChochEvent or nil.
      def process(candle, swing_engine, atr, candle_index, trend_state)
        return nil unless atr&.positive?
        return nil unless trend_state.established?

        if trend_state.bearish?
          check_bullish_choch(candle, swing_engine, atr, candle_index, trend_state)
        elsif trend_state.bullish?
          check_bearish_choch(candle, swing_engine, atr, candle_index, trend_state)
        end
      end

      private

      # In a bearish trend, a break above a swing high = bullish CHOCH
      def check_bullish_choch(candle, swing_engine, atr, candle_index, trend_state)
        # Look for last confirmed high that hasn't been broken yet
        swing = swing_engine.confirmed_highs.last
        return nil unless swing
        return nil if @broken_highs[swing.index]

        level = swing.level
        close = candle.close

        confirming_close = @require_body_close ? close > level : candle.high > level
        return nil unless confirming_close

        displacement = (close - level).abs
        return nil unless displacement >= atr * @min_displacement_atr

        @broken_highs[swing.index] = true
        event = Events::ChochEvent.new(
          timestamp:        candle.timestamp,
          direction:        :bullish,
          broken_level:     level,
          close_price:      close,
          displacement_atr: (displacement / atr).round(2),
          candle_index:     candle_index,
          prior_trend:      :bearish
        )
        trend_state.on_bullish_bos(swing)
        emit(event)
        event
      end

      # In a bullish trend, a break below a swing low = bearish CHOCH
      def check_bearish_choch(candle, swing_engine, atr, candle_index, trend_state)
        swing = swing_engine.confirmed_lows.last
        return nil unless swing
        return nil if @broken_lows[swing.index]

        level = swing.level
        close = candle.close

        confirming_close = @require_body_close ? close < level : candle.low < level
        return nil unless confirming_close

        displacement = (level - close).abs
        return nil unless displacement >= atr * @min_displacement_atr

        @broken_lows[swing.index] = true
        event = Events::ChochEvent.new(
          timestamp:        candle.timestamp,
          direction:        :bearish,
          broken_level:     level,
          close_price:      close,
          displacement_atr: (displacement / atr).round(2),
          candle_index:     candle_index,
          prior_trend:      :bullish
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
