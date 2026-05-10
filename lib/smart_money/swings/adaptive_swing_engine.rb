module SmartMoney
  module Swings
    # Stateful, ATR-aware swing engine. Processes one candle at a time.
    # Emits SwingEvents for confirmed pivot highs and lows.
    # Adapts lookback based on current ATR relative to baseline ATR.
    class AdaptiveSwingEngine
      include Utils::MathUtils

      # Equal-high/low tolerance: fraction of ATR
      EQL_TOLERANCE_FACTOR = 0.1
      # Displacement threshold to classify external vs internal swing
      EXTERNAL_DISPLACEMENT_FACTOR = 0.5

      attr_reader :atr, :confirmed_highs, :confirmed_lows, :candle_count

      def initialize(atr_period: SmartMoney.configuration.default_atr_period,
                     swing_lookback: SmartMoney.configuration.default_swing_lookback)
        @atr_period     = atr_period
        @swing_lookback = swing_lookback
        @atr            = nil
        @baseline_atr   = nil
        @prev_close     = nil
        @candle_count   = 0
        @series         = CandleSeries.new
        @confirmed_highs = []
        @confirmed_lows  = []
        @subscribers    = []
        @pivot_detector = PivotDetector.new(left: 2, right: 2)
      end

      def process(candle)
        @candle_count += 1
        update_atr(candle)
        @series.append(candle)
        update_pivot_detector_lookback
        detect_pivot
        @prev_close = candle.close
      end

      def subscribe(&block)
        @subscribers << block
      end

      def last_confirmed_high
        @confirmed_highs.last
      end

      def last_confirmed_low
        @confirmed_lows.last
      end

      # All confirmed highs above `level`, ordered oldest-first
      def highs_above(level)
        @confirmed_highs.select { |p| p.level > level }
      end

      # All confirmed lows below `level`, ordered oldest-first
      def lows_below(level)
        @confirmed_lows.select { |p| p.level < level }
      end

      private

      def update_atr(candle)
        tr = @prev_close ? Utils::MathUtils.true_range(candle, @prev_close) : candle.range
        @atr = Utils::MathUtils.wilder_atr(@atr, tr, @atr_period)
        @baseline_atr ||= @atr
        # Slowly update baseline (very long smoothing)
        @baseline_atr = (@baseline_atr * 99 + @atr) / 100.0
      end

      def update_pivot_detector_lookback
        return unless @swing_lookback == :adaptive
        return unless @atr && @baseline_atr && @baseline_atr.positive?

        atr_ratio = @atr / @baseline_atr
        n = Utils::MathUtils.clamp(2, 5, (atr_ratio * 3).round)
        @pivot_detector = PivotDetector.new(left: n, right: n) if n != @pivot_detector.left
      end

      def detect_pivot
        pivot = @pivot_detector.detect(@series, @candle_count)
        return unless pivot

        if pivot.direction == :high
          process_pivot_high(pivot)
        else
          process_pivot_low(pivot)
        end
      end

      def process_pivot_high(pivot)
        last = @confirmed_highs.last
        if last && @atr && (pivot.level - last.level).abs < @atr * EQL_TOLERANCE_FACTOR
          # Equal-high cluster — emit as internal EQH marker, don't replace last
          emit_event(pivot, swing_type: :internal, equal_cluster: true)
        else
          swing_type = classify_swing_type(pivot, :high)
          @confirmed_highs << pivot
          emit_event(pivot, swing_type: swing_type, equal_cluster: false)
        end
      end

      def process_pivot_low(pivot)
        last = @confirmed_lows.last
        if last && @atr && (last.level - pivot.level).abs < @atr * EQL_TOLERANCE_FACTOR
          emit_event(pivot, swing_type: :internal, equal_cluster: true)
        else
          swing_type = classify_swing_type(pivot, :low)
          @confirmed_lows << pivot
          emit_event(pivot, swing_type: swing_type, equal_cluster: false)
        end
      end

      def classify_swing_type(pivot, direction)
        return :external unless @atr && @atr.positive?

        if direction == :high
          prev = @confirmed_highs.last
          return :external unless prev
          displacement = (pivot.level - prev.level).abs
        else
          prev = @confirmed_lows.last
          return :external unless prev
          displacement = (prev.level - pivot.level).abs
        end

        displacement >= @atr * EXTERNAL_DISPLACEMENT_FACTOR ? :external : :internal
      end

      def emit_event(pivot, swing_type:, equal_cluster:)
        event = Events::SwingEvent.new(
          timestamp:     pivot.timestamp,
          direction:     pivot.direction,
          level:         pivot.level,
          candle_index:  pivot.index,
          swing_type:    swing_type,
          equal_cluster: equal_cluster
        )
        @subscribers.each { |sub| sub.call(event) }
        event
      end
    end
  end
end
