RSpec.describe SmartMoney::Structure::ChochDetector do
  subject(:detector) { described_class.new(min_displacement_atr: 0.3, require_body_close: true) }

  def make_pivot(direction:, level:, index: 1)
    SmartMoney::Swings::PivotDetector::Pivot.new(
      direction: direction, level: level, index: index, timestamp: Time.at(1_700_000_000)
    )
  end

  def stub_swing(last_high: nil, last_low: nil, highs: [], lows: [])
    double("swing_engine",
      last_confirmed_high: last_high,
      last_confirmed_low:  last_low,
      confirmed_highs:     highs,
      confirmed_lows:      lows
    )
  end

  describe "bullish CHOCH (in bearish trend)" do
    let(:trend_state) do
      ts = SmartMoney::Structure::TrendState.new
      ts.on_bearish_bos(make_pivot(direction: :low, level: 95.0, index: 1))
      ts
    end

    it "fires when body close breaks above swing high in bearish trend" do
      high_pivot = make_pivot(direction: :high, level: 100.0, index: 5)
      swing = stub_swing(last_high: high_pivot, highs: [high_pivot])

      c = candle(open: 100.5, high: 102.0, low: 100.0, close: 101.5, timestamp: Time.at(1_700_001_000))
      event = detector.process(c, swing, 2.0, 10, trend_state)

      expect(event).to be_a(SmartMoney::Events::ChochEvent)
      expect(event.direction).to eq :bullish
      expect(event.prior_trend).to eq :bearish
    end

    it "does not fire when trend is not established" do
      ranging = SmartMoney::Structure::TrendState.new
      high_pivot = make_pivot(direction: :high, level: 100.0, index: 5)
      swing = stub_swing(last_high: high_pivot, highs: [high_pivot])

      c = candle(open: 100.5, high: 102.0, low: 100.0, close: 101.5, timestamp: Time.at(1_700_001_000))
      event = detector.process(c, swing, 2.0, 10, ranging)

      expect(event).to be_nil
    end
  end

  describe "bearish CHOCH (in bullish trend)" do
    let(:trend_state) do
      ts = SmartMoney::Structure::TrendState.new
      ts.on_bullish_bos(make_pivot(direction: :high, level: 105.0, index: 1))
      ts
    end

    it "fires when body close breaks below swing low in bullish trend" do
      low_pivot = make_pivot(direction: :low, level: 98.0, index: 3)
      swing = stub_swing(last_low: low_pivot, lows: [low_pivot])

      c = candle(open: 97.5, high: 98.0, low: 95.5, close: 96.0, timestamp: Time.at(1_700_001_000))
      event = detector.process(c, swing, 2.0, 10, trend_state)

      expect(event).to be_a(SmartMoney::Events::ChochEvent)
      expect(event.direction).to eq :bearish
      expect(event.prior_trend).to eq :bullish
    end
  end
end
