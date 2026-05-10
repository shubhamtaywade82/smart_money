# Shared liquidity contexts.
#
# Each context primes the engine with the precondition described by its name
# so the example body can verify the behavior under those conditions.

RSpec.shared_context "equal_highs_present" do
  let(:engine)          { SmartMoney::Engine.new }
  let(:emitted_events)  { Hash.new { |h, k| h[k] = [] } }
  let(:liquidity_level) { 100 }

  before do
    SmartMoney::Engine::VALID_EVENTS.each do |type|
      engine.subscribe(type) { |e| emitted_events[type] << e }
    end
    bull_sequence(from: liquidity_level - 5, step: 1.0, count: 5).each { |c| engine.on_candle(c) }
    equal_high_pair(level: liquidity_level).each { |c| engine.on_candle(c) }
    bear_sequence(from: liquidity_level - 0.5, step: 0.5, count: 3).each { |c| engine.on_candle(c) }
  end
end

RSpec.shared_context "equal_lows_present" do
  let(:engine)          { SmartMoney::Engine.new }
  let(:emitted_events)  { Hash.new { |h, k| h[k] = [] } }
  let(:liquidity_level) { 100 }

  before do
    SmartMoney::Engine::VALID_EVENTS.each do |type|
      engine.subscribe(type) { |e| emitted_events[type] << e }
    end
    bear_sequence(from: liquidity_level + 5, step: 1.0, count: 5).each { |c| engine.on_candle(c) }
    equal_low_pair(level: liquidity_level).each { |c| engine.on_candle(c) }
    bull_sequence(from: liquidity_level + 0.5, step: 0.5, count: 3).each { |c| engine.on_candle(c) }
  end
end

RSpec.shared_context "liquidity_sweep_confirmed" do
  include_context "equal_highs_present"

  before do
    engine.on_candle(sweep_above(level: liquidity_level, wick: 1.5,
                                 rejection_close: liquidity_level - 1.5))
  end
end

RSpec.shared_context "failed_reclaim" do
  include_context "liquidity_sweep_confirmed"

  before do
    engine.on_candle(displacement_down(close: liquidity_level - 5, size: 5.0,
                                       volume: 10_000))
  end
end
