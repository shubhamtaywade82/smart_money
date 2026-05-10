require "smart_money"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.disable_monkey_patching!
  config.warnings = true
  config.order = :random
  Kernel.srand config.seed

  config.after(:each) { SmartMoney.reset_configuration! }
end

# Helpers for building test candles
module CandleHelpers
  def candle(open:, high:, low:, close:, volume: 1000, timestamp: Time.now)
    SmartMoney::Candle.new(
      timestamp: timestamp,
      open:      open,
      high:      high,
      low:       low,
      close:     close,
      volume:    volume
    )
  end

  # Build a trending sequence of bullish candles ascending by `step`
  def bullish_candles(count, start: 100.0, step: 1.0, wick: 0.2)
    count.times.map do |i|
      base = start + (i * step)
      candle(open: base, high: base + step + wick, low: base - wick, close: base + step,
             timestamp: Time.at(1_700_000_000 + i * 300))
    end
  end

  # Build a trending sequence of bearish candles descending by `step`
  def bearish_candles(count, start: 100.0, step: 1.0, wick: 0.2)
    count.times.map do |i|
      base = start - (i * step)
      candle(open: base, high: base + wick, low: base - step - wick, close: base - step,
             timestamp: Time.at(1_700_000_000 + i * 300))
    end
  end

  # Doji/flat candles (chop)
  def chop_candles(count, around: 100.0, wick: 0.1)
    count.times.map do |i|
      candle(open: around, high: around + wick, low: around - wick, close: around,
             timestamp: Time.at(1_700_000_000 + i * 300))
    end
  end
end

RSpec.configure do |config|
  config.include CandleHelpers
end
