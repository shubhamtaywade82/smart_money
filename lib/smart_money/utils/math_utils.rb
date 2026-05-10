module SmartMoney
  module Utils
    module MathUtils
      module_function

      # Wilder's smoothed ATR: incremental update from previous ATR
      def wilder_atr(prev_atr, true_range, period)
        return true_range if prev_atr.nil?

        (prev_atr * (period - 1) + true_range) / period.to_f
      end

      def true_range(candle, prev_close)
        hl   = candle.high - candle.low
        hpc  = (candle.high - prev_close).abs
        lpc  = (candle.low  - prev_close).abs
        [hl, hpc, lpc].max
      end

      def clamp(min, max, value)
        [[value, min].max, max].min
      end

      def body_high(candle)
        [candle.open, candle.close].max
      end

      def body_low(candle)
        [candle.open, candle.close].min
      end

      def bullish?(candle)
        candle.close > candle.open
      end

      def bearish?(candle)
        candle.close < candle.open
      end
    end
  end
end
