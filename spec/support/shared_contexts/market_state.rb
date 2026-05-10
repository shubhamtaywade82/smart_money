# Shared market-state contexts.
#
# These prime the engine with realistic candle sequences so scenarios can
# focus on the behavior under test, not on setup boilerplate.

RSpec.shared_context "bullish_trend" do
  let(:engine) { SmartMoney::Engine.new }
  let(:emitted_events) { Hash.new { |h, k| h[k] = [] } }

  before do
    SmartMoney::Engine::VALID_EVENTS.each do |type|
      engine.subscribe(type) { |e| emitted_events[type] << e }
    end
    bull_sequence(from: 95, step: 1.5, count: 8).each { |c| engine.on_candle(c) }
  end
end

RSpec.shared_context "bearish_trend" do
  let(:engine) { SmartMoney::Engine.new }
  let(:emitted_events) { Hash.new { |h, k| h[k] = [] } }

  before do
    SmartMoney::Engine::VALID_EVENTS.each do |type|
      engine.subscribe(type) { |e| emitted_events[type] << e }
    end
    bear_sequence(from: 110, step: 1.5, count: 8).each { |c| engine.on_candle(c) }
  end
end

RSpec.shared_context "range_environment" do
  let(:engine) { SmartMoney::Engine.new }
  let(:emitted_events) { Hash.new { |h, k| h[k] = [] } }

  before do
    SmartMoney::Engine::VALID_EVENTS.each do |type|
      engine.subscribe(type) { |e| emitted_events[type] << e }
    end
    8.times do |i|
      engine.on_candle(candle(open: 100, high: 101, low: 99, close: 100,
                              timestamp: Time.at(1_700_000_000 + i * 300)))
    end
  end
end

RSpec.shared_context "high_volatility" do
  let(:engine) { SmartMoney::Engine.new }
  let(:emitted_events) { Hash.new { |h, k| h[k] = [] } }

  before do
    SmartMoney::Engine::VALID_EVENTS.each do |type|
      engine.subscribe(type) { |e| emitted_events[type] << e }
    end
    8.times do |i|
      engine.on_candle(candle(open: 100, high: 110 + i, low: 90 - i, close: 100 + (i * 2),
                              timestamp: Time.at(1_700_000_000 + i * 300)))
    end
  end
end
