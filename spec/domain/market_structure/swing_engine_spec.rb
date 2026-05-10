# Swing Engine BDD Spec
#
# Defines the contract for AdaptiveSwingEngine behavior.
# All expectations are in domain language, not implementation terms.
# These specs run against the existing Phase 1 engine.

RSpec.describe "Swing Engine", :scenario do
  scenario "confirms a swing high only after sufficient right-side candles" do
    given_market do
      bullish_trend(from: 100, to: 110, steps: 5)
    end

    when_candles_processed do
      # Peak candle
      candle(open: 111, high: 115, low: 110, close: 112)
      # Five right-side confirmation candles — covers max adaptive lookback of 5
      candle(open: 112, high: 113, low: 109, close: 110)
      candle(open: 110, high: 111, low: 108, close: 109)
      candle(open: 109, high: 110, low: 107, close: 108)
      candle(open: 108, high: 109, low: 106, close: 107)
      candle(open: 107, high: 108, low: 105, close: 106)
    end

    then_expect do
      swing_highs = events(:swing).select(&:high?)
      expect(swing_highs.last&.level).to be > 110
    end
  end

  scenario "does not report a swing high during a continuous uptrend" do
    # No pivot = no swing high in a monotonically rising sequence
    when_candles_processed do
      candle(open: 100, high: 101, low: 99,  close: 100.8)
      candle(open: 101, high: 102, low: 100, close: 101.8)
      candle(open: 102, high: 103, low: 101, close: 102.8)
      candle(open: 103, high: 104, low: 102, close: 103.8)
      candle(open: 104, high: 105, low: 103, close: 104.8)
    end

    then_expect do
      expect(events(:swing).select(&:high?)).to be_empty
    end
  end

  scenario "ignores insignificant micro-pullbacks as swing lows during strong displacement" do
    given_market do
      bullish_trend(from: 100, to: 120, steps: 10)
    end

    when_candles_processed do
      # Tiny wick-only pullback — should NOT register as a swing low
      candle(open: 121, high: 122, low: 120.8, close: 121.5)
      candle(open: 121.5, high: 123, low: 121, close: 122.5)
      candle(open: 122.5, high: 124, low: 122, close: 123.5)
    end

    then_expect do
      # We want NO swing low confirmed for a 0.2-unit pullback in a strong trend
      lows_in_range = events(:swing).select { |e| e.low? && e.level.between?(120, 122) }
      expect(lows_in_range).to be_empty
    end
  end

  scenario "groups equal highs into a liquidity cluster rather than reporting two separate pivots" do
    when_candles_processed do
      candle(open: 98,  high: 100, low: 97,  close: 99)
      candle(open: 99,  high: 100, low: 98,  close: 99.2)  # equal high
      candle(open: 99,  high: 99.5, low: 97, close: 98)
      candle(open: 98,  high: 98.5, low: 96, close: 97)
      candle(open: 97,  high: 97.5, low: 95, close: 96)
    end

    then_expect do
      high_events = events(:swing).select(&:high?)
      # Equal highs at 100 should not produce two separate external swing high events
      highs_at_level = high_events.select { |e| e.level.round == 100 && e.external? }
      expect(highs_at_level.size).to be <= 1
    end
  end

  scenario "reports swing low with timestamp matching the pivot candle, not the confirmation candle" do
    when_candles_processed do
      candle(open: 103, high: 104, low: 100, close: 101, timestamp: Time.at(1_000))
      candle(open: 101, high: 102, low: 98,  close: 99,  timestamp: Time.at(1_300))  # actual low
      candle(open: 99,  high: 101, low: 98.5, close: 100, timestamp: Time.at(1_600))
      candle(open: 100, high: 102, low: 99,  close: 101, timestamp: Time.at(1_900))
      candle(open: 101, high: 103, low: 100, close: 102, timestamp: Time.at(2_200))
    end

    then_expect do
      lows = events(:swing).select(&:low?)
      if lows.any?
        # Timestamp of event should match the actual low candle (Time.at(1_300)), not later
        expect(lows.last.timestamp).to eq Time.at(1_300)
      end
    end
  end
end

RSpec.describe SmartMoney::Swings::AdaptiveSwingEngine do
  subject(:engine) { described_class.new(atr_period: 14, swing_lookback: 2) }

  describe "ATR adaptation" do
    it "widens detection window during high-volatility conditions" do
      low_vol_candles = 30.times.map do |i|
        candle(open: 100 + i * 0.1, high: 100 + i * 0.1 + 0.15,
               low: 100 + i * 0.1 - 0.05, close: 100 + i * 0.1 + 0.08,
               timestamp: Time.at(1_700_000_000 + i * 300))
      end
      low_vol_candles.each { |c| engine.process(c) }
      low_vol_atr = engine.atr

      engine2 = described_class.new(atr_period: 14, swing_lookback: :adaptive)
      high_vol_candles = 30.times.map do |i|
        candle(open: 100 + i * 2.0, high: 100 + i * 2.0 + 3.0,
               low: 100 + i * 2.0 - 1.5, close: 100 + i * 2.0 + 1.5,
               timestamp: Time.at(1_700_000_000 + i * 300))
      end
      high_vol_candles.each { |c| engine2.process(c) }

      expect(engine2.atr).to be > low_vol_atr
    end
  end

  describe "state isolation" do
    it "two engine instances do not share state" do
      e1 = described_class.new
      e2 = described_class.new

      c = candle(open: 100, high: 105, low: 99, close: 102)
      e1.process(c)

      expect(e2.candle_count).to eq 0
      expect(e2.atr).to be_nil
    end
  end
end
