module SmartMoney
  module Swings
    # Detects pivot highs and lows using left/right bar confirmation.
    # A pivot high at index i requires: candle[i].high > all highs in [i-left..i-1] and [i+1..i+right]
    # Confirmation is deferred until `right` candles have been seen after the candidate.
    class PivotDetector
      Pivot = Data.define(:direction, :level, :index, :timestamp)

      attr_reader :left, :right

      def initialize(left: 2, right: 2)
        @left  = left
        @right = right
      end

      # Returns a confirmed Pivot or nil.
      # `series` is a CandleSeries; `current_index` is the absolute index of the newest candle.
      # Confirmation fires when we have seen `right` candles after the candidate.
      def detect(series, current_index)
        return nil if series.size < left + right + 1

        candidate_pos = -(right + 1)
        candidate = series[candidate_pos]
        return nil unless candidate

        left_candles  = (1..left).map  { |i| series[candidate_pos - i] }.compact
        right_candles = (1..right).map { |i| series[candidate_pos + i] }.compact

        return nil if left_candles.size < left || right_candles.size < right

        check_high(candidate, left_candles, right_candles, current_index - right) ||
          check_low(candidate, left_candles, right_candles, current_index - right)
      end

      private

      def check_high(candidate, left_candles, right_candles, index)
        return nil unless left_candles.all? { |c| candidate.high > c.high }
        return nil unless right_candles.all? { |c| candidate.high > c.high }

        Pivot.new(direction: :high, level: candidate.high, index: index, timestamp: candidate.timestamp)
      end

      def check_low(candidate, left_candles, right_candles, index)
        return nil unless left_candles.all? { |c| candidate.low < c.low }
        return nil unless right_candles.all? { |c| candidate.low < c.low }

        Pivot.new(direction: :low, level: candidate.low, index: index, timestamp: candidate.timestamp)
      end
    end
  end
end
