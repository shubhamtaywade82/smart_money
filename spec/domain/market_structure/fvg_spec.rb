RSpec.describe "fair value gap lifecycle", :fvg do
  let(:engine) { SmartMoney::Engine.new }
  let(:fvgs)   { [] }

  before { engine.subscribe(:fvg) { |e| fvgs << e } }

  context "during a bullish displacement leg" do
    context "when the third candle's low does not retrace into the first candle's high" do
      before do
        engine.on_candle(candle(open: 100, high: 102, low: 99, close: 101, timestamp: Time.at(1_000)))
        engine.on_candle(displacement_up(close: 108, size: 7.0, volume: 9000, ts: Time.at(1_300)))
        engine.on_candle(candle(open: 108, high: 109, low: 105.5, close: 107, timestamp: Time.at(1_600)))
      end

      it "registers a bullish fair value gap" do
        expect(fvgs).to contain_bullish_fvg
      end

      it "places the lower boundary at the first candle's high" do
        expect(fvgs.last.lower).to be_within(0.2).of(102)
      end

      it "places the upper boundary at the third candle's low" do
        expect(fvgs.last.upper).to be_within(0.2).of(105.5)
      end
    end
  end

  context "during a bearish displacement leg" do
    context "when the third candle's high does not retrace into the first candle's low" do
      before do
        engine.on_candle(candle(open: 106, high: 108,   low: 104.5, close: 107, timestamp: Time.at(1_000)))
        engine.on_candle(displacement_down(close: 99, size: 8.0, volume: 9000, ts: Time.at(1_300)))
        engine.on_candle(candle(open: 99,  high: 101.5, low: 97.5,  close: 100, timestamp: Time.at(1_600)))
      end

      it "registers a bearish fair value gap" do
        expect(fvgs).to contain_bearish_fvg
      end

      it "places the upper boundary at the first candle's low" do
        expect(fvgs.last.upper).to be_within(0.2).of(104.5)
      end

      it "places the lower boundary at the third candle's high" do
        expect(fvgs.last.lower).to be_within(0.2).of(101.5)
      end
    end
  end

  context "when surrounding candles overlap and leave no imbalance" do
    before do
      engine.on_candle(candle(open: 100, high: 104, low: 99,  close: 103, timestamp: Time.at(1_000)))
      engine.on_candle(candle(open: 103, high: 106, low: 102, close: 105, timestamp: Time.at(1_300)))
      engine.on_candle(candle(open: 105, high: 107, low: 103, close: 106, timestamp: Time.at(1_600)))
    end

    it "does not register any fair value gap" do
      expect(fvgs).to be_empty
    end
  end

  context "after a bullish FVG has formed" do
    before do
      engine.on_candle(candle(open: 100, high: 102, low: 99, close: 101, timestamp: Time.at(1_000)))
      engine.on_candle(displacement_up(close: 109, size: 8.0, volume: 10_000, ts: Time.at(1_300)))
      engine.on_candle(candle(open: 109, high: 110, low: 106, close: 108, timestamp: Time.at(1_600)))
    end

    context "when price retraces into the gap but does not close beyond its lower edge" do
      before do
        engine.on_candle(candle(open: 108, high: 108.5, low: 104, close: 105, timestamp: Time.at(1_900)))
      end

      it "marks the gap as partially filled" do
        partial = fvgs.select(&:partially_filled?)
        expect(partial).not_to be_empty
      end
    end

    context "when price closes decisively below the lower edge of the gap" do
      before do
        engine.on_candle(candle(open: 105, high: 105.5, low: 100, close: 101, timestamp: Time.at(1_900)))
      end

      it "marks the gap as fully mitigated" do
        expect(fvgs).to contain_mitigated_fvg
      end
    end
  end
end
