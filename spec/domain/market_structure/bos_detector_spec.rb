RSpec.describe "break of structure detection", :market_structure do
  subject(:detector) do
    SmartMoney::Structure::BosDetector.new(min_displacement_atr: 0.3, require_body_close: true)
  end

  let(:trend_state) { SmartMoney::Structure::TrendState.new }

  def stub_swing_engine(last_high: nil, last_low: nil, highs: [], lows: [])
    double("swing_engine",
           last_confirmed_high: last_high,
           last_confirmed_low:  last_low,
           confirmed_highs:     highs,
           confirmed_lows:      lows)
  end

  def make_pivot(direction:, level:, index: 1)
    SmartMoney::Swings::PivotDetector::Pivot.new(direction: direction, level: level,
                                                 index: index, timestamp: Time.at(1_700_000_000))
  end

  context "during bullish trend continuation" do
    let(:high_pivot) { make_pivot(direction: :high, level: 100.0, index: 5) }
    let(:swing)      { stub_swing_engine(last_high: high_pivot, highs: [high_pivot]) }

    context "when price closes above the prior swing high with sufficient displacement" do
      let(:event) do
        c = candle(open: 100.5, high: 102.0, low: 100.0, close: 101.5,
                   timestamp: Time.at(1_700_001_000))
        detector.process(c, swing, 2.0, 10, trend_state)
      end

      it "confirms a bullish break of structure" do
        expect(event).to be_a(SmartMoney::Events::BosEvent)
        expect(event.direction).to eq :bullish
      end

      it "records the broken swing level on the event" do
        expect(event.broken_level).to eq 100.0
      end
    end

    context "when only the wick exceeds the swing high" do
      let(:event) do
        c = candle(open: 99.5, high: 101.0, low: 99.0, close: 99.8,
                   timestamp: Time.at(1_700_001_000))
        detector.process(c, swing, 2.0, 10, trend_state)
      end

      it "rejects the structure break and emits no event" do
        expect(event).to be_nil
      end
    end

    context "when displacement falls below the minimum ATR threshold" do
      let(:event) do
        c = candle(open: 100.05, high: 100.2, low: 99.8, close: 100.1,
                   timestamp: Time.at(1_700_001_000))
        detector.process(c, swing, 2.0, 10, trend_state)
      end

      it "ignores the low-momentum break" do
        expect(event).to be_nil
      end
    end

    context "when the same swing has already been broken" do
      it "does not emit a duplicate BOS event on a subsequent close above the same level" do
        c1 = candle(open: 100.5, high: 102.0, low: 100.0, close: 101.5, timestamp: Time.at(1_700_001_000))
        c2 = candle(open: 101.5, high: 103.0, low: 101.0, close: 102.5, timestamp: Time.at(1_700_001_300))

        detector.process(c1, swing, 2.0, 10, trend_state)
        second = detector.process(c2, swing, 2.0, 11, trend_state)

        expect(second).to be_nil
      end
    end
  end

  context "during bearish trend continuation" do
    let(:low_pivot) { make_pivot(direction: :low, level: 98.0, index: 3) }
    let(:swing)     { stub_swing_engine(last_low: low_pivot, lows: [low_pivot]) }

    context "when price closes below the prior swing low with sufficient displacement" do
      let(:event) do
        c = candle(open: 97.0, high: 97.5, low: 95.5, close: 96.0,
                   timestamp: Time.at(1_700_001_000))
        detector.process(c, swing, 2.0, 10, trend_state)
      end

      it "confirms a bearish break of structure" do
        expect(event).to be_a(SmartMoney::Events::BosEvent)
        expect(event.direction).to eq :bearish
      end

      it "records the broken swing level on the event" do
        expect(event.broken_level).to eq 98.0
      end
    end
  end

  context "execution wiring" do
    context "when subscribers are attached" do
      it "delivers each emitted BOS event to every subscriber" do
        received = []
        detector.subscribe { |e| received << e }

        high_pivot = make_pivot(direction: :high, level: 100.0, index: 5)
        swing      = stub_swing_engine(last_high: high_pivot, highs: [high_pivot])
        c          = candle(open: 100.5, high: 102.0, low: 100.0, close: 101.5,
                            timestamp: Time.at(1_700_001_000))
        detector.process(c, swing, 2.0, 10, trend_state)

        expect(received.size).to eq 1
        expect(received.first).to be_a(SmartMoney::Events::BosEvent)
      end
    end

    context "when ATR has not yet warmed up" do
      it "returns nil instead of raising or emitting" do
        c = candle(open: 100, high: 102, low: 99, close: 101)
        expect(detector.process(c, stub_swing_engine, nil, 1, trend_state)).to be_nil
      end
    end
  end
end
