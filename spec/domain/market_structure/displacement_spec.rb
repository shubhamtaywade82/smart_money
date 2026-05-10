# Displacement Engine BDD Spec
#
# Defines the contract for SmartMoney::Imbalance::Displacement.
# Displacement is the force behind valid structure breaks.
# Without it, BOS/CHOCH are noise.
#
# These specs are RED until Phase 2 implements the DisplacementEngine.

RSpec.describe "Displacement Engine", :scenario do
  scenario "detects bullish displacement from a large-body bullish candle" do
    when_candles_processed do
      # ATR context
      candle(open: 100, high: 101, low: 99,  close: 100.5)
      candle(open: 100, high: 101, low: 99,  close: 100.3)
      candle(open: 100, high: 101, low: 99,  close: 100.4)
      # Displacement candle: 3x ATR body, minimal wicks
      displacement_up(close: 104, size: 4.0, volume: 8000)
    end

    then_expect do
      displacements = events(:displacement)
      bullish = displacements.select { |e| e.direction == :bullish }
      expect(bullish).not_to be_empty
    end
  end

  scenario "detects bearish displacement from a large-body bearish candle" do
    when_candles_processed do
      candle(open: 100, high: 101, low: 99, close: 100.5)
      candle(open: 100, high: 101, low: 99, close: 100.3)
      candle(open: 100, high: 101, low: 99, close: 100.4)
      displacement_down(close: 96, size: 4.0, volume: 8000)
    end

    then_expect do
      displacements = events(:displacement)
      bearish = displacements.select { |e| e.direction == :bearish }
      expect(bearish).not_to be_empty
    end
  end

  scenario "rejects a low-momentum candle as displacement even if it exceeds a swing level" do
    when_candles_processed do
      # Doji that happens to close above a level — no displacement
      candle(open: 99.9, high: 100.3, low: 99.7, close: 100.1)
    end

    then_expect do
      expect(events(:displacement)).to be_empty
    end
  end

  scenario "requires volume expansion for displacement confirmation" do
    when_candles_processed do
      candle(open: 100, high: 101, low: 99,  close: 100.4)
      candle(open: 100, high: 101, low: 99,  close: 100.3)
      # Large body but thin volume — weak displacement
      candle(open: 100, high: 104, low: 99.8, close: 103.5, volume: 100)
    end

    then_expect do
      displacements = events(:displacement)
      strong = displacements.select { |e| e.respond_to?(:strength) && e.strength == :strong }
      expect(strong).to be_empty
    end
  end

  scenario "scores multi-candle displacement sequences higher than single-candle breaks" do
    when_candles_processed do
      candle(open: 100, high: 101, low: 99,  close: 100.5)
      displacement_up(close: 102, size: 2.0, volume: 4000)
      displacement_up(close: 104, size: 2.0, volume: 5000)
      displacement_up(close: 106, size: 2.0, volume: 6000)
    end

    then_expect do
      displacements = events(:displacement)
      multi_candle = displacements.select { |e| e.respond_to?(:candle_count) && e.candle_count > 1 }
      expect(multi_candle.last&.score).to be > displacements.first&.score
    end
  end

  scenario "identifies the origin candle of a displacement sequence" do
    when_candles_processed do
      candle(open: 100, high: 101, low: 99, close: 100.5, timestamp: Time.at(1_000))
      displacement_up(close: 104, size: 4.0, volume: 8000, ts: Time.at(1_300))
    end

    then_expect do
      displacements = events(:displacement)
      expect(displacements.last&.origin_candle&.timestamp).to eq Time.at(1_300)
    end
  end
end

RSpec.describe "Displacement: imbalance (FVG) creation", :scenario do
  scenario "displacement creates a bullish fair value gap" do
    when_candles_processed do
      candle(open: 100, high: 101.5, low: 99,   close: 101,   timestamp: Time.at(1_000))
      displacement_up(close: 107, size: 6.0, ts: Time.at(1_300))
      candle(open: 107, high: 108,   low: 105.5, close: 106.5, timestamp: Time.at(1_600))
    end

    then_expect do
      fvgs = events(:fvg)
      bullish = fvgs.select { |e| e.direction == :bullish }
      # FVG range: between candle[0].high (101.5) and candle[2].low (105.5)
      expect(bullish).not_to be_empty
      expect(bullish.last.upper).to be_within(0.1).of(105.5)
      expect(bullish.last.lower).to be_within(0.1).of(101.5)
    end
  end

  scenario "displacement creates a bearish fair value gap" do
    when_candles_processed do
      candle(open: 106, high: 107,   low: 104.5, close: 105,   timestamp: Time.at(1_000))
      displacement_down(close: 99, size: 6.0, ts: Time.at(1_300))
      candle(open: 99,  high: 100.5, low: 98,    close: 100,   timestamp: Time.at(1_600))
    end

    then_expect do
      fvgs = events(:fvg)
      bearish = fvgs.select { |e| e.direction == :bearish }
      expect(bearish).not_to be_empty
    end
  end

  scenario "does not create an FVG when candles overlap (no gap)" do
    when_candles_processed do
      candle(open: 100, high: 103, low: 99,  close: 102, timestamp: Time.at(1_000))
      candle(open: 102, high: 105, low: 101, close: 104, timestamp: Time.at(1_300))
      candle(open: 104, high: 106, low: 102, close: 105, timestamp: Time.at(1_600))
    end

    then_expect do
      expect(events(:fvg)).to be_empty
    end
  end
end
