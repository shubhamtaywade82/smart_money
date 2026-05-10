RSpec.describe "adaptive swing detection", :market_structure do
  subject(:engine) { SmartMoney::Swings::AdaptiveSwingEngine.new(atr_period: 14, swing_lookback: 2) }

  def feed(candles)
    candles.each { |c| engine.process(c) }
  end

  context "during a clear bullish-then-bearish reversal" do
    it "emits a confirmed swing high once enough right-side bars have arrived" do
      events = []
      engine.subscribe { |e| events << e }

      feed(bullish_candles(6, start: 100.0, step: 1.0) +
           bearish_candles(5, start: 106.5, step: 1.0))

      expect(events.select(&:high?)).not_to be_empty
    end
  end

  context "during a clear bearish-then-bullish reversal" do
    it "emits a confirmed swing low once enough right-side bars have arrived" do
      events = []
      engine.subscribe { |e| events << e }

      feed(bearish_candles(6, start: 100.0, step: 1.0) +
           bullish_candles(5, start:  93.5, step: 1.0))

      expect(events.select(&:low?)).not_to be_empty
    end
  end

  context "warming up the volatility model" do
    it "exposes nil ATR until the first candle has been processed" do
      expect(engine.atr).to be_nil
    end

    it "produces a positive ATR after a steady stream of candles" do
      feed(bullish_candles(20, start: 100.0, step: 0.5))

      expect(engine.atr).to be_a(Float)
      expect(engine.atr).to be > 0
    end
  end

  context "incremental processing invariants" do
    it "produces identical swing levels on a fresh engine fed the same candles" do
      candles = bullish_candles(10, start: 100.0, step: 2.0) +
                bearish_candles(10, start: 120.0, step: 2.0)

      runs = 2.times.map do
        captured = []
        e = SmartMoney::Swings::AdaptiveSwingEngine.new(atr_period: 14, swing_lookback: 2)
        e.subscribe { |evt| captured << evt }
        candles.each { |c| e.process(c) }
        captured.map(&:level)
      end

      expect(runs.first).to eq runs.last
    end
  end

  context "near-equal highs in low volatility" do
    it "processes a clustered-highs sequence without raising or stalling" do
      ts = Time.at(1_700_000_000)
      feed([
        candle(open: 100,    high: 102,    low: 99,    close: 100.5, timestamp: ts),
        candle(open: 100,    high: 105,    low: 99.5,  close: 101,   timestamp: ts + 300),
        candle(open: 101,    high: 103,    low: 100,   close: 101.5, timestamp: ts + 600),
        candle(open: 101.5,  high: 105.05, low: 101,   close: 104,   timestamp: ts + 900),
        candle(open: 104,    high: 104.5,  low: 102,   close: 103,   timestamp: ts + 1200),
        candle(open: 103,    high: 103.5,  low: 101,   close: 102,   timestamp: ts + 1500),
        candle(open: 102,    high: 102.5,  low: 100,   close: 101,   timestamp: ts + 1800)
      ])

      expect(engine.candle_count).to eq 7
    end
  end
end
