RSpec.describe SmartMoney::Structure::BosDetector do
  subject(:detector) { described_class.new(min_displacement_atr: 0.3, require_body_close: true) }

  let(:trend_state) { SmartMoney::Structure::TrendState.new }

  def stub_swing_engine(last_high: nil, last_low: nil, highs: [], lows: [])
    double("swing_engine",
      last_confirmed_high: last_high,
      last_confirmed_low:  last_low,
      confirmed_highs:     highs,
      confirmed_lows:      lows
    )
  end

  def make_pivot(direction:, level:, index: 1)
    SmartMoney::Swings::PivotDetector::Pivot.new(
      direction: direction, level: level, index: index, timestamp: Time.at(1_700_000_000)
    )
  end

  describe "bullish BOS" do
    it "fires when body close exceeds swing high with sufficient displacement" do
      high_pivot = make_pivot(direction: :high, level: 100.0, index: 5)
      swing = stub_swing_engine(last_high: high_pivot, highs: [high_pivot])

      # Close at 101.5, ATR = 2.0 → displacement = 1.5 / 2.0 = 0.75 >= 0.3 ✓
      c = candle(open: 100.5, high: 102.0, low: 100.0, close: 101.5, timestamp: Time.at(1_700_001_000))
      event = detector.process(c, swing, 2.0, 10, trend_state)

      expect(event).to be_a(SmartMoney::Events::BosEvent)
      expect(event.direction).to eq :bullish
      expect(event.broken_level).to eq 100.0
    end

    it "does not fire on wick-only break when require_body_close is true" do
      high_pivot = make_pivot(direction: :high, level: 100.0, index: 5)
      swing = stub_swing_engine(last_high: high_pivot, highs: [high_pivot])

      # Close at 99.8 (body below level), high at 101 (wick above)
      c = candle(open: 99.5, high: 101.0, low: 99.0, close: 99.8, timestamp: Time.at(1_700_001_000))
      event = detector.process(c, swing, 2.0, 10, trend_state)

      expect(event).to be_nil
    end

    it "does not fire when displacement is too small" do
      high_pivot = make_pivot(direction: :high, level: 100.0, index: 5)
      swing = stub_swing_engine(last_high: high_pivot, highs: [high_pivot])

      # Close at 100.1, ATR = 2.0 → displacement = 0.1 / 2.0 = 0.05 < 0.3
      c = candle(open: 100.05, high: 100.2, low: 99.8, close: 100.1, timestamp: Time.at(1_700_001_000))
      event = detector.process(c, swing, 2.0, 10, trend_state)

      expect(event).to be_nil
    end

    it "does not fire twice for the same swing level" do
      high_pivot = make_pivot(direction: :high, level: 100.0, index: 5)
      swing = stub_swing_engine(last_high: high_pivot, highs: [high_pivot])

      c1 = candle(open: 100.5, high: 102.0, low: 100.0, close: 101.5, timestamp: Time.at(1_700_001_000))
      c2 = candle(open: 101.5, high: 103.0, low: 101.0, close: 102.5, timestamp: Time.at(1_700_001_300))

      detector.process(c1, swing, 2.0, 10, trend_state)
      event2 = detector.process(c2, swing, 2.0, 11, trend_state)

      expect(event2).to be_nil
    end
  end

  describe "bearish BOS" do
    it "fires when body close breaks below swing low with sufficient displacement" do
      low_pivot = make_pivot(direction: :low, level: 98.0, index: 3)
      swing = stub_swing_engine(last_low: low_pivot, lows: [low_pivot])

      # Close at 96.0, ATR = 2.0 → displacement = 2.0 / 2.0 = 1.0 >= 0.3 ✓
      c = candle(open: 97.0, high: 97.5, low: 95.5, close: 96.0, timestamp: Time.at(1_700_001_000))
      event = detector.process(c, swing, 2.0, 10, trend_state)

      expect(event).to be_a(SmartMoney::Events::BosEvent)
      expect(event.direction).to eq :bearish
      expect(event.broken_level).to eq 98.0
    end
  end

  describe "subscribers" do
    it "notifies subscribers when BOS fires" do
      received = []
      detector.subscribe { |e| received << e }

      high_pivot = make_pivot(direction: :high, level: 100.0, index: 5)
      swing = stub_swing_engine(last_high: high_pivot, highs: [high_pivot])
      c = candle(open: 100.5, high: 102.0, low: 100.0, close: 101.5, timestamp: Time.at(1_700_001_000))
      detector.process(c, swing, 2.0, 10, trend_state)

      expect(received.size).to eq 1
      expect(received.first).to be_a(SmartMoney::Events::BosEvent)
    end
  end

  describe "with nil ATR" do
    it "returns nil safely" do
      swing = stub_swing_engine
      c = candle(open: 100, high: 102, low: 99, close: 101)
      expect(detector.process(c, swing, nil, 1, trend_state)).to be_nil
    end
  end
end
