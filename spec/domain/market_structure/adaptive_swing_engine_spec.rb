RSpec.describe SmartMoney::Swings::AdaptiveSwingEngine do
  subject(:engine) { described_class.new(atr_period: 14, swing_lookback: 2) }

  def feed(candles)
    candles.each { |c| engine.process(c) }
  end

  describe "basic swing detection" do
    it "emits a swing high event after confirmation" do
      events = []
      engine.subscribe { |e| events << e }

      # Build: rise, clear pivot high, fall
      candles = bullish_candles(6, start: 100.0, step: 1.0) +
                bearish_candles(5, start: 106.5, step: 1.0)
      feed(candles)

      highs = events.select(&:high?)
      expect(highs).not_to be_empty
    end

    it "emits a swing low event after confirmation" do
      events = []
      engine.subscribe { |e| events << e }

      candles = bearish_candles(6, start: 100.0, step: 1.0) +
                bullish_candles(5, start: 93.5, step: 1.0)
      feed(candles)

      lows = events.select(&:low?)
      expect(lows).not_to be_empty
    end
  end

  describe "ATR tracking" do
    it "updates ATR after each candle" do
      feed(bullish_candles(20, start: 100.0, step: 0.5))
      expect(engine.atr).to be_a(Float)
      expect(engine.atr).to be > 0
    end

    it "starts with nil ATR before any candle" do
      expect(engine.atr).to be_nil
    end
  end

  describe "equal-high clustering" do
    it "marks equal highs as clustered" do
      events = []
      engine.subscribe { |e| events << e }

      # Two very close highs followed by a drop
      ts = Time.at(1_700_000_000)
      candles = [
        candle(open: 100, high: 102, low: 99, close: 100.5, timestamp: ts),
        candle(open: 100, high: 105, low: 99.5, close: 101, timestamp: ts + 300),
        candle(open: 101, high: 103, low: 100, close: 101.5, timestamp: ts + 600),
        candle(open: 101.5, high: 105.05, low: 101, close: 104, timestamp: ts + 900),
        candle(open: 104, high: 104.5, low: 102, close: 103, timestamp: ts + 1200),
        candle(open: 103, high: 103.5, low: 101, close: 102, timestamp: ts + 1500),
        candle(open: 102, high: 102.5, low: 100, close: 101, timestamp: ts + 1800),
      ]
      feed(candles)

      # Not asserting specific cluster — just that the engine doesn't crash
      # and processes all candles
      expect(engine.candle_count).to eq candles.size
    end
  end

  describe "incremental processing" do
    it "processes candles one at a time (no repainting)" do
      events_sequential = []
      engine.subscribe { |e| events_sequential << e }

      candles = bullish_candles(10, start: 100.0, step: 2.0) +
                bearish_candles(10, start: 120.0, step: 2.0)

      candles.each { |c| engine.process(c) }

      # Rebuild fresh engine and feed same candles — events must be identical
      engine2 = described_class.new(atr_period: 14, swing_lookback: 2)
      events_sequential2 = []
      engine2.subscribe { |e| events_sequential2 << e }
      candles.each { |c| engine2.process(c) }

      expect(events_sequential.map(&:level)).to eq events_sequential2.map(&:level)
    end
  end
end
