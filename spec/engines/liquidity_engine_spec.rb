# Liquidity Engine BDD Spec
#
# Defines the contract for SmartMoney::Liquidity::SweepDetector,
# EqualHighsLows detector, and LiquidityPool.
#
# These specs are RED until Phase 2 implements the LiquidityEngine.
# They serve as the executable design contract.

RSpec.describe "Liquidity Engine", :scenario do
  scenario "detects equal highs as resting buy-side liquidity" do
    when_candles_processed do
      # Two candles touching the same high — engineered liquidity target
      candle(open: 97, high: 100, low: 96, close: 98)
      candle(open: 98, high: 100, low: 97, close: 98.5)
      # Pullback — leaving the level intact (resting)
      candle(open: 98, high: 99,  low: 96, close: 97)
      candle(open: 97, high: 98,  low: 95, close: 96)
    end

    then_expect do
      # LiquidityEngine not yet implemented — mark pending
      pending "Phase 2: LiquidityEngine not yet implemented"
      pools = events(:liquidity_pool)
      bsl = pools.select { |e| e.side == :buy_side && e.level.round == 100 }
      expect(bsl).not_to be_empty
    end
  end

  scenario "detects equal lows as resting sell-side liquidity" do
    when_candles_processed do
      candle(open: 103, high: 104, low: 100, close: 102)
      candle(open: 102, high: 103, low: 100, close: 101.5)
      candle(open: 102, high: 103, low: 101, close: 102)
      candle(open: 103, high: 104, low: 102, close: 103)
    end

    then_expect do
      pending "Phase 2: LiquidityEngine not yet implemented"
      pools = events(:liquidity_pool)
      ssl = pools.select { |e| e.side == :sell_side && e.level.round == 100 }
      expect(ssl).not_to be_empty
    end
  end

  scenario "marks liquidity as swept when price trades through and rejects" do
    given_market do
      equal_highs(at: 100)
    end

    when_candles_processed do
      # Wick pierces above 100 then closes back below — sweep
      sweep_above(level: 100, wick: 1.5, rejection_close: 98.5)
    end

    then_expect do
      pending "Phase 2: LiquidityEngine not yet implemented"
      liquidity_to_be_swept(:buy_side)
    end
  end

  scenario "does not classify continuation acceptance as a sweep" do
    given_market do
      equal_highs(at: 100)
    end

    when_candles_processed do
      # Price CLOSES above 100 with body — this is acceptance, not a sweep
      candle(open: 99, high: 102, low: 98.5, close: 101.5)
    end

    then_expect do
      skip "Phase 2: LiquidityEngine not yet implemented"
      sweeps = events(:sweep)
      expect(sweeps.select { |e| e.side == :buy_side }).to be_empty
    end
  end

  scenario "classifies aggressive sweeps with displacement candles as high-velocity" do
    given_market do
      equal_highs(at: 200)
    end

    when_candles_processed do
      # Big displacement candle — sweeps above 200 and closes well below
      candle(open: 199, high: 204, low: 195, close: 196, volume: 10_000)
    end

    then_expect do
      pending "Phase 2: LiquidityEngine not yet implemented"
      sweeps = events(:sweep)
      aggressive = sweeps.select { |e| e.respond_to?(:velocity) && e.velocity == :aggressive }
      expect(aggressive).not_to be_empty
    end
  end

  scenario "sweep followed by displacement constitutes a valid liquidity sweep reversal" do
    given_market do
      equal_highs(at: 100)
    end

    when_candles_processed do
      sweep_above(level: 100, wick: 1.0, rejection_close: 99)
      displacement_down(close: 96, size: 4.0)
    end

    then_expect do
      pending "Phase 2: LiquidityEngine not yet implemented"
      liquidity_to_be_swept(:buy_side)
      displacement_to_be_bearish
    end
  end

  scenario "reclaim after sweep invalidates the sweep signal" do
    given_market do
      equal_highs(at: 100)
    end

    when_candles_processed do
      sweep_above(level: 100, wick: 0.5, rejection_close: 99.5)
      # Price immediately climbs back and closes above — reclaim
      candle(open: 99.5, high: 102, low: 99, close: 101.5)
    end

    then_expect do
      pending "Phase 2: LiquidityEngine not yet implemented"
      sweeps = events(:sweep)
      reclaimed = sweeps.select { |e| e.respond_to?(:reclaimed?) && e.reclaimed? }
      expect(reclaimed).not_to be_empty
    end
  end
end

RSpec.describe "Liquidity: equal-high/low tolerance", :scenario do
  scenario "groups highs within ATR tolerance as the same liquidity level" do
    when_candles_processed do
      # Two highs 0.05 apart — should be treated as same EQH level
      candle(open: 97, high: 100.00, low: 96, close: 98)
      candle(open: 98, high: 100.04, low: 97, close: 98.5)
      candle(open: 98, high: 99,     low: 96, close: 97)
      candle(open: 97, high: 98,     low: 95, close: 96)
    end

    then_expect do
      pending "Phase 2: LiquidityEngine not yet implemented"
      pools = events(:liquidity_pool)
      expect(pools.size).to eq 1
      expect(pools.first.level).to be_within(0.1).of(100)
    end
  end

  scenario "does not group highs separated by more than ATR as the same level" do
    when_candles_processed do
      # 2.0 apart — different liquidity levels, not a cluster
      candle(open: 97, high: 100, low: 96, close: 98)
      candle(open: 98, high: 102, low: 97, close: 99)
      candle(open: 99, high: 100, low: 97, close: 98)
      candle(open: 98, high: 99,  low: 96, close: 97)
    end

    then_expect do
      pending "Phase 2: LiquidityEngine not yet implemented"
      pools = events(:liquidity_pool)
      expect(pools.size).to eq 2
    end
  end
end
