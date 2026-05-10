# Fair Value Gap (FVG) Engine BDD Spec
#
# Defines the contract for SmartMoney::Imbalance::FairValueGap.
# FVGs are three-candle imbalances created during displacement.
#
# RED until Phase 3.

RSpec.describe "Fair Value Gap Engine", :scenario do
  scenario "detects a bullish FVG during upward displacement" do
    when_candles_processed do
      candle(open: 100, high: 102, low: 99,  close: 101, timestamp: Time.at(1_000))
      displacement_up(close: 108, size: 7.0, volume: 9000, ts: Time.at(1_300))
      candle(open: 108, high: 109, low: 105.5, close: 107, timestamp: Time.at(1_600))
    end

    then_expect do
      pending "Phase 3: FVG not yet implemented"
      fvgs = events(:fvg)
      bullish = fvgs.select { |e| e.direction == :bullish }
      expect(bullish).not_to be_empty
      # Gap: between candle[0].high (102) and candle[2].low (105.5)
      gap = bullish.last
      expect(gap.lower).to be_within(0.2).of(102)
      expect(gap.upper).to be_within(0.2).of(105.5)
    end
  end

  scenario "detects a bearish FVG during downward displacement" do
    when_candles_processed do
      candle(open: 106, high: 108, low: 104.5, close: 107, timestamp: Time.at(1_000))
      displacement_down(close: 99, size: 8.0, volume: 9000, ts: Time.at(1_300))
      candle(open: 99,  high: 101.5, low: 97.5, close: 100, timestamp: Time.at(1_600))
    end

    then_expect do
      pending "Phase 3: FVG not yet implemented"
      fvgs = events(:fvg)
      bearish = fvgs.select { |e| e.direction == :bearish }
      expect(bearish).not_to be_empty
      gap = bearish.last
      expect(gap.upper).to be_within(0.2).of(104.5)
      expect(gap.lower).to be_within(0.2).of(101.5)
    end
  end

  scenario "does not create an FVG when candles overlap" do
    when_candles_processed do
      candle(open: 100, high: 104, low: 99,  close: 103, timestamp: Time.at(1_000))
      candle(open: 103, high: 106, low: 102, close: 105, timestamp: Time.at(1_300))
      candle(open: 105, high: 107, low: 103, close: 106, timestamp: Time.at(1_600))
    end

    then_expect do
      skip "Phase 3: FVG not yet implemented"
      expect(events(:fvg)).to be_empty
    end
  end

  scenario "tracks partial fill of a bullish FVG" do
    when_candles_processed do
      candle(open: 100, high: 102, low: 99,   close: 101, timestamp: Time.at(1_000))
      displacement_up(close: 109, size: 8.0, volume: 10_000, ts: Time.at(1_300))
      candle(open: 109, high: 110, low: 106,  close: 108, timestamp: Time.at(1_600))
      # Pullback into gap — partial fill
      candle(open: 108, high: 108.5, low: 104, close: 105, timestamp: Time.at(1_900))
    end

    then_expect do
      pending "Phase 3: FVG not yet implemented"
      fvgs = events(:fvg)
      partially_filled = fvgs.select { |e| e.respond_to?(:partially_filled?) && e.partially_filled? }
      expect(partially_filled).not_to be_empty
    end
  end

  scenario "marks FVG as fully mitigated after complete traversal" do
    when_candles_processed do
      candle(open: 100, high: 102.5, low: 99,   close: 101.5, timestamp: Time.at(1_000))
      displacement_up(close: 108, size: 7.0, volume: 8000, ts: Time.at(1_300))
      candle(open: 108, high: 109,  low: 105.5, close: 107,   timestamp: Time.at(1_600))
      # Price returns and closes below the FVG lower boundary
      candle(open: 105, high: 105.5, low: 100, close: 101, timestamp: Time.at(1_900))
    end

    then_expect do
      pending "Phase 3: FVG not yet implemented"
      fvgs = events(:fvg)
      mitigated = fvgs.select { |e| e.respond_to?(:mitigated?) && e.mitigated? }
      expect(mitigated).not_to be_empty
    end
  end
end
