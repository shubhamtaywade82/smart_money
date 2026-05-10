RSpec.describe "displacement detection", :displacement do
  let(:engine)         { SmartMoney::Engine.new }
  let(:displacements)  { [] }

  before { engine.subscribe(:displacement) { |e| displacements << e } }

  context "during low-volatility build-up" do
    before do
      engine.on_candle(candle(open: 100, high: 101, low: 99, close: 100.5))
      engine.on_candle(candle(open: 100, high: 101, low: 99, close: 100.3))
      engine.on_candle(candle(open: 100, high: 101, low: 99, close: 100.4))
    end

    context "when a large-body bullish candle prints" do
      before { engine.on_candle(displacement_up(close: 104, size: 4.0, volume: 8000)) }

      it "confirms bullish displacement" do
        expect(displacements).to have_displacement(:bullish)
      end
    end

    context "when a large-body bearish candle prints" do
      before { engine.on_candle(displacement_down(close: 96, size: 4.0, volume: 8000)) }

      it "confirms bearish displacement" do
        expect(displacements).to have_displacement(:bearish)
      end
    end

    context "when a doji prints with marginal body" do
      before { engine.on_candle(candle(open: 99.9, high: 100.3, low: 99.7, close: 100.1)) }

      it "rejects the candle as displacement" do
        expect(displacements).to be_empty
      end
    end
  end

  context "during a multi-candle bullish sequence" do
    before do
      engine.on_candle(candle(open: 100, high: 101, low: 99, close: 100.5))
      engine.on_candle(displacement_up(close: 102, size: 2.0, volume: 4000))
      engine.on_candle(displacement_up(close: 104, size: 2.0, volume: 5000))
      engine.on_candle(displacement_up(close: 106, size: 2.0, volume: 6000))
    end

    it "scores the streak higher than the first single-candle displacement" do
      streak_score    = displacements.last&.score
      first_score     = displacements.first&.score

      expect(streak_score).to be > first_score
    end

    it "tags the streak with a candle_count greater than one" do
      streak = displacements.select { |e| e.candle_count > 1 }
      expect(streak).not_to be_empty
    end
  end

  context "with thin volume on an otherwise large-body candle" do
    before do
      engine.on_candle(candle(open: 100, high: 101, low: 99, close: 100.4))
      engine.on_candle(candle(open: 100, high: 101, low: 99, close: 100.3))
      engine.on_candle(candle(open: 100, high: 104, low: 99.8, close: 103.5, volume: 100))
    end

    it "does not classify the candle as institutional-strength displacement" do
      strong = displacements.select(&:strong?)
      expect(strong).to be_empty
    end
  end

  context "identifying the origin candle of a streak" do
    before do
      engine.on_candle(candle(open: 100, high: 101, low: 99, close: 100.5,
                              timestamp: Time.at(1_000)))
      engine.on_candle(displacement_up(close: 104, size: 4.0, volume: 8000,
                                       ts: Time.at(1_300)))
    end

    it "exposes the first candle of the displacement leg as origin_candle" do
      expect(displacements.last&.origin_candle&.timestamp).to eq Time.at(1_300)
    end
  end
end

RSpec.describe "fair value gap creation from displacement", :fvg do
  let(:engine) { SmartMoney::Engine.new }
  let(:fvgs)   { [] }

  before { engine.subscribe(:fvg) { |e| fvgs << e } }

  context "during a bullish displacement leg" do
    before do
      engine.on_candle(candle(open: 100, high: 101.5, low: 99,    close: 101,   timestamp: Time.at(1_000)))
      engine.on_candle(displacement_up(close: 107, size: 6.0, ts: Time.at(1_300)))
      engine.on_candle(candle(open: 107, high: 108,   low: 105.5, close: 106.5, timestamp: Time.at(1_600)))
    end

    it "registers a bullish fair value gap between the surrounding candles" do
      bullish = fvgs.select(&:bullish?)
      expect(bullish).not_to be_empty
    end

    it "places the upper boundary at the third candle's low" do
      expect(fvgs.last.upper).to be_within(0.1).of(105.5)
    end

    it "places the lower boundary at the first candle's high" do
      expect(fvgs.last.lower).to be_within(0.1).of(101.5)
    end
  end

  context "during a bearish displacement leg" do
    before do
      engine.on_candle(candle(open: 106, high: 107,   low: 104.5, close: 105,   timestamp: Time.at(1_000)))
      engine.on_candle(displacement_down(close: 99, size: 6.0, ts: Time.at(1_300)))
      engine.on_candle(candle(open: 99,  high: 100.5, low: 98,    close: 100,   timestamp: Time.at(1_600)))
    end

    it "registers a bearish fair value gap" do
      expect(fvgs.select(&:bearish?)).not_to be_empty
    end
  end

  context "when surrounding candles overlap (no gap left behind)" do
    before do
      engine.on_candle(candle(open: 100, high: 103, low: 99,  close: 102, timestamp: Time.at(1_000)))
      engine.on_candle(candle(open: 102, high: 105, low: 101, close: 104, timestamp: Time.at(1_300)))
      engine.on_candle(candle(open: 104, high: 106, low: 102, close: 105, timestamp: Time.at(1_600)))
    end

    it "registers no fair value gap" do
      expect(fvgs).to be_empty
    end
  end
end
