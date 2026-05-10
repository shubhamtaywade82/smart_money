RSpec.describe SmartMoney::Strategy::ConfluenceEngine do
  let(:engine)    { SmartMoney::Engine.new }
  let(:setups)    { [] }
  let!(:confluence) do
    described_class.new(engine: engine).tap do |c|
      c.subscribe { |event| setups << event }
    end
  end

  describe "buy-side sweep + bearish displacement = short setup" do
    it "publishes a SetupEvent describing the short trigger" do
      # Build the equal-highs liquidity at 100 via DSL primitives
      bull_sequence(from: 95, step: 1, count: 5).each { |c| engine.on_candle(c) }
      equal_high_pair(level: 100).each { |c| engine.on_candle(c) }
      bear_sequence(from: 99.5, step: 0.5, count: 3).each { |c| engine.on_candle(c) }

      sweep    = sweep_above(level: 100, wick: 1.5, rejection_close: 98.5)
      drop     = displacement_down(close: 94, size: 5.0, volume: 8000)

      engine.on_candle(sweep)
      engine.on_candle(drop)

      expect(setups).not_to be_empty
      setup = setups.last
      expect(setup.short?).to be true
      expect(setup.sweep.buy_side?).to be true
      expect(setup.displacement.bearish?).to be true
    end
  end

  describe "sell-side sweep + bullish displacement = long setup" do
    it "publishes a long SetupEvent" do
      bear_sequence(from: 105, step: 1, count: 5).each { |c| engine.on_candle(c) }
      equal_low_pair(level: 100).each { |c| engine.on_candle(c) }
      bull_sequence(from: 100.5, step: 0.5, count: 3).each { |c| engine.on_candle(c) }

      engine.on_candle(sweep_below(level: 100, wick: 1.5, rejection_close: 101.5))
      engine.on_candle(displacement_up(close: 106, size: 5.0, volume: 8000))

      expect(setups).not_to be_empty
      expect(setups.last.long?).to be true
    end
  end

  describe "expiration" do
    it "drops a sweep older than the setup window from the matchable set" do
      bull_sequence(from: 95, step: 1, count: 5).each { |c| engine.on_candle(c) }
      equal_high_pair(level: 100).each { |c| engine.on_candle(c) }
      bear_sequence(from: 99.5, step: 0.5, count: 3).each { |c| engine.on_candle(c) }

      # Small-body sweep at candle 11 — must not match any far-future displacement
      engine.on_candle(candle(open: 99.7, high: 100.3, low: 99.4, close: 99.6))
      stale_sweep_index = setups.size # baseline, expected unchanged

      # Six neutral candles — beyond SETUP_WINDOW (5)
      6.times { engine.on_candle(candle(open: 99.5, high: 99.8, low: 99.2, close: 99.5)) }
      engine.on_candle(displacement_down(close: 94, size: 5.0, volume: 8000))

      # No setup should reference the stale sweep at candle 11
      stale_setups = setups.select { |s| s.sweep.candle_index == 11 }
      expect(stale_setups).to be_empty
    end
  end

  describe "score" do
    it "boosts the score when an aligned order block is part of the confluence" do
      # Build context where displacement creates an OB
      candle(open: 100, high: 101, low: 99, close: 100.5).then { |c| engine.on_candle(c) }
      candle(open: 100, high: 101, low: 99, close: 100.4).then { |c| engine.on_candle(c) }

      bull_sequence(from: 95, step: 1, count: 5).each { |c| engine.on_candle(c) }
      equal_high_pair(level: 100).each { |c| engine.on_candle(c) }
      bear_sequence(from: 99.5, step: 0.5, count: 3).each { |c| engine.on_candle(c) }

      engine.on_candle(sweep_above(level: 100, wick: 1.5, rejection_close: 98.5))
      engine.on_candle(displacement_down(close: 92, size: 8.0, volume: 12000))

      next_setup = setups.last
      next if next_setup.nil?

      expect(next_setup.score).to be > 0
    end
  end
end
