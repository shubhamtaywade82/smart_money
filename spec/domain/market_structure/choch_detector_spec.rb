RSpec.describe "change of character detection", :market_structure do
  subject(:detector) do
    SmartMoney::Structure::ChochDetector.new(min_displacement_atr: 0.3, require_body_close: true)
  end

  def make_pivot(direction:, level:, index: 1)
    SmartMoney::Swings::PivotDetector::Pivot.new(direction: direction, level: level,
                                                 index: index, timestamp: Time.at(1_700_000_000))
  end

  def stub_swing(last_high: nil, last_low: nil, highs: [], lows: [])
    double("swing_engine",
           last_confirmed_high: last_high,
           last_confirmed_low:  last_low,
           confirmed_highs:     highs,
           confirmed_lows:      lows)
  end

  context "during bearish market structure" do
    let(:trend_state) do
      ts = SmartMoney::Structure::TrendState.new
      ts.on_bearish_bos(make_pivot(direction: :low, level: 95.0, index: 1))
      ts
    end

    context "when price closes above an external swing high with displacement" do
      let(:event) do
        high_pivot = make_pivot(direction: :high, level: 100.0, index: 5)
        swing      = stub_swing(last_high: high_pivot, highs: [high_pivot])
        c          = candle(open: 100.5, high: 102.0, low: 100.0, close: 101.5,
                            timestamp: Time.at(1_700_001_000))
        detector.process(c, swing, 2.0, 10, trend_state)
      end

      it "confirms a bullish change of character" do
        expect(event).to be_a(SmartMoney::Events::ChochEvent)
        expect(event.direction).to eq :bullish
      end

      it "records the bearish trend that was reversed" do
        expect(event.prior_trend).to eq :bearish
      end
    end
  end

  context "during bullish market structure" do
    let(:trend_state) do
      ts = SmartMoney::Structure::TrendState.new
      ts.on_bullish_bos(make_pivot(direction: :high, level: 105.0, index: 1))
      ts
    end

    context "when price closes below an external swing low with displacement" do
      let(:event) do
        low_pivot = make_pivot(direction: :low, level: 98.0, index: 3)
        swing     = stub_swing(last_low: low_pivot, lows: [low_pivot])
        c         = candle(open: 97.5, high: 98.0, low: 95.5, close: 96.0,
                           timestamp: Time.at(1_700_001_000))
        detector.process(c, swing, 2.0, 10, trend_state)
      end

      it "confirms a bearish change of character" do
        expect(event).to be_a(SmartMoney::Events::ChochEvent)
        expect(event.direction).to eq :bearish
      end

      it "records the bullish trend that was reversed" do
        expect(event.prior_trend).to eq :bullish
      end
    end
  end

  context "during a ranging market with no established trend" do
    it "ignores even a decisive break because there is no character to change from" do
      ranging    = SmartMoney::Structure::TrendState.new
      high_pivot = make_pivot(direction: :high, level: 100.0, index: 5)
      swing      = stub_swing(last_high: high_pivot, highs: [high_pivot])
      c          = candle(open: 100.5, high: 102.0, low: 100.0, close: 101.5,
                          timestamp: Time.at(1_700_001_000))

      expect(detector.process(c, swing, 2.0, 10, ranging)).to be_nil
    end
  end
end
