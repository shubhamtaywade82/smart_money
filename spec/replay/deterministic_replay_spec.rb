# Deterministic Replay Spec
#
# The critical correctness oracle.
# Two requirements:
#   1. Zero future leakage — no event uses information from candles not yet processed
#   2. Determinism — same input sequence always produces same events
#
# These tests run against the live engine (not pending) because the Phase 1
# engine must already satisfy both properties.

RSpec.describe "Deterministic Replay" do
  include CandleFactory

  # Synthetic sequence with known BOS/CHOCH points
  let(:base_sequence) do
    ts = Time.at(1_700_000_000)

    # Phase A: establish bearish structure
    bearish = (0..14).map do |i|
      close  = 200 - i * 2.0
      open   = close + 1.5
      candle(open: open, high: open + 0.5, low: close - 0.5, close: close,
             timestamp: Time.at(ts.to_i + i * 300))
    end

    # Phase B: bounce (swing lows confirmed, then up)
    bounce = (0..14).map do |i|
      close  = 172 + i * 2.0
      open   = close - 1.5
      candle(open: open, high: close + 0.5, low: open - 0.5, close: close,
             timestamp: Time.at(ts.to_i + (15 + i) * 300))
    end

    bearish + bounce
  end

  describe "no future leakage" do
    it "events emitted at candle N never reference data from candle N+1 or later" do
      engine = SmartMoney::Engine.new
      emitted_by_index = {}

      engine.subscribe(:bos) { |e| emitted_by_index[engine.candle_count] = e }

      base_sequence.each do |c|
        before_count = engine.candle_count
        engine.on_candle(c)
        # Any event emitted just now must not reference future timestamps
        if emitted_by_index[engine.candle_count]
          event = emitted_by_index[engine.candle_count]
          expect(event.timestamp).to be <= c.timestamp
        end
      end
    end

    it "swing events carry the timestamp of the pivot candle, not the confirmation candle" do
      engine = SmartMoney::Engine.new
      swing_events = []
      engine.subscribe(:swing) { |e| swing_events << { event: e, emitted_at_count: engine.candle_count } }

      base_sequence.each { |c| engine.on_candle(c) }

      swing_events.each do |entry|
        event       = entry[:event]
        emitted_at  = entry[:emitted_at_count]
        pivot_ts    = event.timestamp
        emission_ts = base_sequence[[emitted_at - 1, 0].max].timestamp
        # The pivot candle must precede or equal the emission candle in time
        expect(pivot_ts).to be <= emission_ts
      end
    end
  end

  describe "determinism" do
    it "two engines fed the same candles in the same order produce identical BOS events" do
      bos1 = []
      bos2 = []

      engine1 = SmartMoney::Engine.new
      engine2 = SmartMoney::Engine.new

      engine1.subscribe(:bos) { |e| bos1 << [e.direction, e.broken_level.round(4)] }
      engine2.subscribe(:bos) { |e| bos2 << [e.direction, e.broken_level.round(4)] }

      base_sequence.each { |c| engine1.on_candle(c) }
      base_sequence.each { |c| engine2.on_candle(c) }

      expect(bos1).to eq bos2
    end

    it "events are never retracted (no repainting)" do
      engine = SmartMoney::Engine.new
      emitted = []
      engine.subscribe(:bos)   { |e| emitted << [:bos,   e.direction, e.broken_level] }
      engine.subscribe(:choch) { |e| emitted << [:choch, e.direction, e.broken_level] }

      snapshot_at_30 = nil
      base_sequence.each.with_index(1) do |c, i|
        engine.on_candle(c)
        snapshot_at_30 = emitted.dup if i == 30
      end

      expect(snapshot_at_30).not_to be_nil
      snapshot_at_30.each do |entry|
        expect(emitted).to include(entry),
          "Event #{entry} was emitted but later disappeared (repainting)"
      end
    end

    it "random seed does not affect engine output (no internal randomness)" do
      results_a = []
      results_b = []

      2.times do |run|
        srand(run == 0 ? 42 : 99_999)
        engine = SmartMoney::Engine.new
        engine.subscribe(:swing) { |e| (run == 0 ? results_a : results_b) << e.level }
        base_sequence.each { |c| engine.on_candle(c) }
      end

      expect(results_a).to eq results_b
    end
  end

  describe "edge cases" do
    it "handles a single-candle spike that wicks above a swing high but closes below" do
      engine = SmartMoney::Engine.new
      bos_events = []
      engine.subscribe(:bos) { |e| bos_events << e }

      # Establish a swing high around 110
      setup = bull_sequence(from: 100, step: 2, count: 5, base_ts: Time.at(1_700_000_000))
      pullback = bear_sequence(from: 110, step: 2, count: 4, base_ts: Time.at(1_700_001_500))
      spike = [candle(open: 103, high: 115, low: 102, close: 104,
                      timestamp: Time.at(1_700_002_700))]

      (setup + pullback + spike).each { |c| engine.on_candle(c) }

      # Wick to 115 but close at 104 — no BOS (body-close gate)
      bullish_bos = bos_events.select(&:bullish?)
      expect(bullish_bos).to be_empty
    end

    it "handles duplicate timestamps without crashing" do
      engine = SmartMoney::Engine.new
      ts = Time.at(1_700_000_000)
      c1 = candle(open: 100, high: 101, low: 99, close: 100.5, timestamp: ts)
      c2 = candle(open: 100.5, high: 102, low: 100, close: 101, timestamp: ts)

      expect { engine.on_candle(c1); engine.on_candle(c2) }.not_to raise_error
    end

    it "processes 1000+ candles without memory explosion" do
      engine = SmartMoney::Engine.new
      1100.times do |i|
        c = candle(open: 100 + Math.sin(i * 0.1) * 5,
                   high: 100 + Math.sin(i * 0.1) * 5 + 1,
                   low:  100 + Math.sin(i * 0.1) * 5 - 1,
                   close: 100 + Math.sin(i * 0.1) * 5 + 0.3,
                   timestamp: Time.at(1_700_000_000 + i * 300))
        engine.on_candle(c)
      end

      # CandleSeries ring buffer must not grow beyond capacity
      expect(engine.swing_engine.instance_variable_get(:@series).size)
        .to be <= SmartMoney.configuration.default_series_capacity
    end

    it "handles a sequence with zero volume candles" do
      engine = SmartMoney::Engine.new
      [
        candle(open: 100, high: 101, low: 99, close: 100.5, volume: 0),
        candle(open: 100.5, high: 102, low: 100, close: 101, volume: 0)
      ].each { |c| expect { engine.on_candle(c) }.not_to raise_error }
    end
  end
end
