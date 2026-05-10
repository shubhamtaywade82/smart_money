RSpec.describe "smc engine orchestration", :integration do
  subject(:engine) { SmartMoney::Engine.new(timeframe: "5m") }

  context "freshly constructed" do
    it "reports zero candles processed" do
      expect(engine.candle_count).to eq 0
    end

    it "starts in a ranging trend state" do
      expect(engine.trend_state.state).to eq :ranging
    end
  end

  context "registering subscribers" do
    context "when an unknown event type is requested" do
      it "raises a clear ArgumentError so misconfiguration is caught early" do
        expect { engine.subscribe(:unknown) {} }
          .to raise_error(ArgumentError, /Unknown event type/)
      end
    end

    context "when subscribing to a known event type" do
      it "returns the engine to support fluent chaining" do
        expect(engine.subscribe(:bos) {}).to be engine
      end
    end

    context "when multiple subscribers register for the same event" do
      it "fans out each event to every subscriber" do
        a, b = [], []
        engine.subscribe(:swing) { |e| a << e }
        engine.subscribe(:swing) { |e| b << e }

        candles = bullish_candles(10, start: 100.0, step: 2.0) +
                  bearish_candles(6,  start: 122.0, step: 2.0)
        candles.each { |c| engine.on_candle(c) }

        expect(a.size).to eq b.size
      end
    end
  end

  context "ingesting candles" do
    it "increments the processed-candle counter" do
      3.times { engine.on_candle(candle(open: 100, high: 101, low: 99, close: 100.5)) }
      expect(engine.candle_count).to eq 3
    end

    it "returns the engine from on_candle for chaining" do
      c = candle(open: 100, high: 101, low: 99, close: 100.5)
      expect(engine.on_candle(c)).to be engine
    end
  end

  context "during a clear bullish trend" do
    it "emits swing events to subscribers" do
      swings = []
      engine.subscribe(:swing) { |e| swings << e }

      candles = bullish_candles(8, start: 100.0, step: 1.5) +
                bearish_candles(6, start: 113.0, step: 1.5)
      candles.each { |c| engine.on_candle(c) }

      expect(swings).not_to be_empty
    end
  end

  context "execution invariants" do
    context "when the same candles are replayed on a fresh engine" do
      it "produces an identical BOS sequence with no internal randomness" do
        candles = bullish_candles(15, start: 100.0, step: 1.0) +
                  bearish_candles(15, start: 116.0, step: 1.0) +
                  bullish_candles(10, start: 101.0, step: 1.5)

        runs = 2.times.map do
          received = []
          e = SmartMoney::Engine.new(timeframe: "1m")
          e.subscribe(:bos) { |evt| received << [evt.direction, evt.broken_level] }
          candles.each { |c| e.on_candle(c) }
          received
        end

        expect(runs.first).to eq runs.last
      end
    end

    context "when more candles arrive after some events have already been emitted" do
      it "never retracts a previously-emitted structural event" do
        emitted = []
        engine.subscribe(:bos)   { |e| emitted << [:bos,   e.timestamp] }
        engine.subscribe(:choch) { |e| emitted << [:choch, e.timestamp] }

        candles = bullish_candles(20, start: 100.0, step: 1.0) +
                  bearish_candles(20, start: 121.0, step: 1.0)

        snapshot = nil
        candles.each.with_index(1) do |c, i|
          engine.on_candle(c)
          snapshot = emitted.dup if i == 30
        end

        snapshot&.each { |entry| expect(emitted).to include(entry) }
      end
    end
  end

  context "configuration" do
    it "honors the configured ATR period when warming up indicators" do
      SmartMoney.configure { |c| c.default_atr_period = 5 }
      e = SmartMoney::Engine.new
      5.times { |i| e.on_candle(candle(open: 100 + i, high: 102 + i, low: 99 + i, close: 101 + i)) }
      expect(e.swing_engine.atr).not_to be_nil
    end
  end
end
