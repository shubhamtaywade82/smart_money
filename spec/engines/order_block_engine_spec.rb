# Order Block Engine BDD Spec
#
# Defines the contract for SmartMoney::OrderBlocks.
# Valid OBs require: displacement origin + imbalance + structure interaction.
# NOT every opposite candle.
#
# RED until Phase 3.

RSpec.describe "Order Block Engine", :scenario do
  scenario "detects a bullish order block from the last bearish candle before bullish displacement" do
    when_candles_processed do
      # Context candles
      candle(open: 103, high: 104, low: 100, close: 101)
      candle(open: 101, high: 102, low: 99,  close: 100)
      # Last bearish candle before impulse — this becomes the OB
      candle(open: 100, high: 101, low: 97,  close: 97.5, timestamp: Time.at(3_000))
      # Displacement candle
      displacement_up(close: 107, size: 9.5, volume: 8000, ts: Time.at(3_300))
    end

    then_expect do
      pending "Phase 3: OrderBlockEngine not yet implemented"
      obs = events(:order_block)
      bullish = obs.select { |e| e.direction == :bullish }
      expect(bullish).not_to be_empty
      # OB high/low should span the last bearish candle before displacement
      expect(bullish.last.origin_candle.timestamp).to eq Time.at(3_000)
    end
  end

  scenario "detects a bearish order block from the last bullish candle before bearish displacement" do
    when_candles_processed do
      candle(open: 97, high: 100, low: 96,  close: 99)
      candle(open: 99, high: 101, low: 98,  close: 100)
      candle(open: 100, high: 103, low: 99, close: 102.5, timestamp: Time.at(3_000))
      displacement_down(close: 92, size: 10.0, volume: 9000, ts: Time.at(3_300))
    end

    then_expect do
      pending "Phase 3: OrderBlockEngine not yet implemented"
      obs = events(:order_block)
      bearish = obs.select { |e| e.direction == :bearish }
      expect(bearish).not_to be_empty
    end
  end

  scenario "marks an order block as mitigated after price retests it" do
    given_market do
      equal_lows(at: 95)
      bullish_trend(from: 97, to: 110, steps: 8)
    end

    when_candles_processed do
      # Displacement establishes OB around 97-100
      displacement_up(close: 110, size: 12, volume: 10_000)
      # Pullback INTO the OB zone
      bear_sequence(from: 109, step: 1.5, count: 6, base_ts: Time.at(CandleFactory::BASE_TIMESTAMP.to_i + 15_000))
        .each { |c| candle(**c.to_h.except(:timestamp), timestamp: c.timestamp) } rescue nil
    end

    then_expect do
      pending "Phase 3: OrderBlockEngine not yet implemented"
      obs = events(:order_block)
      mitigated = obs.select { |e| e.respond_to?(:mitigated?) && e.mitigated? }
      expect(mitigated).not_to be_empty
    end
  end

  scenario "invalidates a bullish order block on a strong body close below its low" do
    given_market do
      bullish_trend(from: 95, to: 108, steps: 8)
    end

    when_candles_processed do
      displacement_up(close: 112, size: 6, volume: 7000)
      # Strong close below the OB zone
      candle(open: 100, high: 101, low: 93, close: 94, volume: 8000)
    end

    then_expect do
      pending "Phase 3: OrderBlockEngine not yet implemented"
      obs = events(:order_block)
      invalidated = obs.select { |e| e.respond_to?(:invalidated?) && e.invalidated? }
      expect(invalidated).not_to be_empty
    end
  end

  scenario "does not mark every bearish candle as a bullish order block" do
    when_candles_processed do
      # Random sequence with bearish candles — no displacement context
      candle(open: 102, high: 103, low: 99, close: 100)
      candle(open: 100, high: 101, low: 98, close: 99)
      candle(open: 99,  high: 100, low: 97, close: 98)
    end

    then_expect do
      skip "Phase 3: OrderBlockEngine not yet implemented"
      obs = events(:order_block)
      expect(obs).to be_empty
    end
  end
end
