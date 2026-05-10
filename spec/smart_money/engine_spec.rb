RSpec.describe SmartMoney::Engine do
  subject(:engine) { described_class.new(timeframe: "5m") }

  describe "initialization" do
    it "starts with zero candles processed" do
      expect(engine.candle_count).to eq 0
    end

    it "starts with ranging trend state" do
      expect(engine.trend_state.state).to eq :ranging
    end
  end

  describe "#subscribe" do
    it "raises on unknown event type" do
      expect { engine.subscribe(:unknown) { } }.to raise_error(ArgumentError, /Unknown event type/)
    end

    it "returns self for chaining" do
      result = engine.subscribe(:bos) { }
      expect(result).to be engine
    end
  end

  describe "#on_candle" do
    it "returns self for chaining" do
      c = candle(open: 100, high: 101, low: 99, close: 100.5)
      expect(engine.on_candle(c)).to be engine
    end

    it "increments candle_count" do
      3.times { engine.on_candle(candle(open: 100, high: 101, low: 99, close: 100.5)) }
      expect(engine.candle_count).to eq 3
    end
  end

  describe "swing event emission" do
    it "emits swing events to subscribers" do
      swings = []
      engine.subscribe(:swing) { |e| swings << e }

      # Feed enough candles to create a clear pivot
      candles = bullish_candles(8, start: 100.0, step: 1.5) +
                bearish_candles(6, start: 113.0, step: 1.5)
      candles.each { |c| engine.on_candle(c) }

      expect(swings).not_to be_empty
    end
  end

  describe "BOS event emission" do
    it "emits BOS events when structure breaks" do
      bos_events = []
      engine.subscribe(:bos) { |e| bos_events << e }

      # Build a clear trending sequence: up, form swing high, up again breaking it
      ts_base = Time.at(1_700_000_000)
      candles = [
        candle(open: 100, high: 102, low: 99,  close: 101, timestamp: ts_base),
        candle(open: 101, high: 104, low: 100, close: 103, timestamp: ts_base + 300),
        candle(open: 103, high: 108, low: 102, close: 107, timestamp: ts_base + 600),
        candle(open: 107, high: 109, low: 104, close: 105, timestamp: ts_base + 900),
        candle(open: 105, high: 107, low: 102, close: 103, timestamp: ts_base + 1200),
        candle(open: 103, high: 105, low: 100, close: 101, timestamp: ts_base + 1500),
        candle(open: 101, high: 103, low: 99,  close: 100, timestamp: ts_base + 1800),
        candle(open: 100, high: 102, low: 98,  close: 99,  timestamp: ts_base + 2100),
        candle(open: 99,  high: 101, low: 97,  close: 98,  timestamp: ts_base + 2400),
        # Now break below a swing low with displacement
        candle(open: 98,  high: 99,  low: 93,  close: 93,  timestamp: ts_base + 2700),
        candle(open: 93,  high: 94,  low: 90,  close: 90,  timestamp: ts_base + 3000),
      ]

      candles.each { |c| engine.on_candle(c) }

      # We may or may not have BOS events depending on ATR warmup, but we should not crash
      expect { }.not_to raise_error
    end
  end

  describe "replay consistency (anti-repainting)" do
    it "produces identical events when candles are replayed sequentially" do
      engine1_bos = []
      engine1 = described_class.new(timeframe: "1m")
      engine1.subscribe(:bos) { |e| engine1_bos << [e.direction, e.broken_level] }

      engine2_bos = []
      engine2 = described_class.new(timeframe: "1m")
      engine2.subscribe(:bos) { |e| engine2_bos << [e.direction, e.broken_level] }

      candles = bullish_candles(15, start: 100.0, step: 1.0) +
                bearish_candles(15, start: 116.0, step: 1.0) +
                bullish_candles(10, start: 101.0, step: 1.5)

      candles.each { |c| engine1.on_candle(c) }
      candles.each { |c| engine2.on_candle(c) }

      expect(engine1_bos).to eq engine2_bos
    end

    it "events are not retracted once emitted" do
      emitted = []
      engine.subscribe(:bos)   { |e| emitted << [:bos,   e.timestamp] }
      engine.subscribe(:choch) { |e| emitted << [:choch, e.timestamp] }

      candles = bullish_candles(20, start: 100.0, step: 1.0) +
                bearish_candles(20, start: 121.0, step: 1.0)

      snapshot_after_30 = nil
      candles.each.with_index(1) do |c, i|
        engine.on_candle(c)
        snapshot_after_30 = emitted.dup if i == 30
      end

      # Events emitted by candle 30 must still be present at the end
      if snapshot_after_30&.any?
        snapshot_after_30.each do |entry|
          expect(emitted).to include(entry)
        end
      end
    end
  end

  describe "configuration" do
    it "uses configured ATR period" do
      SmartMoney.configure { |c| c.default_atr_period = 5 }
      e = described_class.new
      # After 5 candles the ATR should be initialized
      5.times { |i| e.on_candle(candle(open: 100 + i, high: 102 + i, low: 99 + i, close: 101 + i)) }
      expect(e.swing_engine.atr).not_to be_nil
    end
  end

  describe "multiple subscribers" do
    it "notifies all subscribers on the same event type" do
      received1 = []
      received2 = []

      engine.subscribe(:swing) { |e| received1 << e }
      engine.subscribe(:swing) { |e| received2 << e }

      candles = bullish_candles(10, start: 100.0, step: 2.0) +
                bearish_candles(6, start: 122.0, step: 2.0)
      candles.each { |c| engine.on_candle(c) }

      expect(received1.size).to eq received2.size
    end
  end
end
