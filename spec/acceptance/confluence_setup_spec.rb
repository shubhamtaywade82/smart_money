# Acceptance Spec: Confluence-Driven Setup
#
# A complete institutional setup, expressed in domain language:
#   1. Resting buy-side liquidity above prior highs
#   2. A sweep takes that liquidity
#   3. Bearish displacement confirms the rejection
#   4. ConfluenceEngine emits a short SetupEvent
#
# Reads like a trading playbook, not an implementation check.

RSpec.describe "Acceptance: Sweep-Then-Displacement Confluence" do
  let(:engine)     { SmartMoney::Engine.new }
  let(:setups)    { [] }
  let(:all_events) { [] }
  let!(:confluence) do
    SmartMoney::Strategy::ConfluenceEngine.new(engine: engine).tap do |c|
      c.subscribe { |e| setups << e }
    end
  end

  before do
    SmartMoney::Engine::VALID_EVENTS.each do |type|
      engine.subscribe(type) { |e| all_events << e }
    end
  end

  context "buy-side sweep then bearish displacement" do
    before do
      bull_sequence(from: 95, step: 1, count: 5).each { |c| engine.on_candle(c) }
      equal_high_pair(level: 100).each { |c| engine.on_candle(c) }
      bear_sequence(from: 99.5, step: 0.5, count: 3).each { |c| engine.on_candle(c) }

      engine.on_candle(sweep_above(level: 100, wick: 1.5, rejection_close: 98.5))
      engine.on_candle(displacement_down(close: 93, size: 6.0, volume: 12_000))
    end

    it "registers the buy-side liquidity pool that gets swept" do
      expect(all_events).to contain_buy_side_pool(near: 100)
    end

    it "fires a buy-side sweep event" do
      expect(all_events).to contain_buy_side_sweep
    end

    it "emits bearish displacement after the sweep" do
      expect(all_events).to contain_bearish_displacement
    end

    it "publishes a short SetupEvent combining sweep + displacement" do
      expect(setups).not_to be_empty
      setup = setups.last
      expect(setup.short?).to be true
      expect(setup.sweep.buy_side?).to be true
      expect(setup.displacement.bearish?).to be true
      expect(setup.score).to be > 0
    end
  end

  context "sell-side sweep then bullish displacement" do
    before do
      bear_sequence(from: 105, step: 1, count: 5).each { |c| engine.on_candle(c) }
      equal_low_pair(level: 100).each { |c| engine.on_candle(c) }
      bull_sequence(from: 100.5, step: 0.5, count: 3).each { |c| engine.on_candle(c) }

      engine.on_candle(sweep_below(level: 100, wick: 1.5, rejection_close: 101.5))
      engine.on_candle(displacement_up(close: 107, size: 6.0, volume: 12_000))
    end

    it "registers the sell-side pool" do
      expect(all_events).to contain_sell_side_pool(near: 100)
    end

    it "fires a sell-side sweep" do
      expect(all_events).to contain_sell_side_sweep
    end

    it "publishes a long SetupEvent" do
      expect(setups).not_to be_empty
      expect(setups.last.long?).to be true
    end
  end

  context "no-setup scenarios" do
    it "produces no setup when price closes through liquidity (continuation, not sweep)" do
      bull_sequence(from: 95, step: 1, count: 5).each { |c| engine.on_candle(c) }
      equal_high_pair(level: 100).each { |c| engine.on_candle(c) }
      bear_sequence(from: 99.5, step: 0.5, count: 3).each { |c| engine.on_candle(c) }

      engine.on_candle(candle(open: 99, high: 102, low: 98.5, close: 101.5))

      sweeps = all_events.select { |e| e.is_a?(SmartMoney::Events::SweepEvent) && !e.reclaimed? }
      expect(sweeps.select(&:buy_side?)).to be_empty
      expect(setups).to be_empty
    end
  end
end
