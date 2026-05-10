RSpec.describe "resting liquidity registration", :liquidity do
  let(:engine)         { SmartMoney::Engine.new }
  let(:emitted_pools)  { [] }
  let(:emitted_sweeps) { [] }

  before do
    engine.subscribe(:liquidity_pool) { |e| emitted_pools  << e }
    engine.subscribe(:sweep)          { |e| emitted_sweeps << e }
  end

  context "when two candles touch the same high before pulling back" do
    before do
      engine.on_candle(candle(open: 97, high: 100, low: 96, close: 98))
      engine.on_candle(candle(open: 98, high: 100, low: 97, close: 98.5))
      engine.on_candle(candle(open: 98, high: 99,  low: 96, close: 97))
      engine.on_candle(candle(open: 97, high: 98,  low: 95, close: 96))
    end

    it "registers a buy-side liquidity pool at the engineered highs" do
      expect(emitted_pools).to contain_buy_side_pool(near: 100)
    end
  end

  context "when two candles touch the same low before recovery" do
    before do
      engine.on_candle(candle(open: 103, high: 104, low: 100, close: 102))
      engine.on_candle(candle(open: 102, high: 103, low: 100, close: 101.5))
      engine.on_candle(candle(open: 102, high: 103, low: 101, close: 102))
      engine.on_candle(candle(open: 103, high: 104, low: 102, close: 103))
    end

    it "registers a sell-side liquidity pool at the engineered lows" do
      expect(emitted_pools).to contain_sell_side_pool(near: 100)
    end
  end

  context "ATR-tolerance clustering" do
    context "when adjacent highs sit within ATR tolerance" do
      before do
        engine.on_candle(candle(open: 97, high: 100.00, low: 96, close: 98))
        engine.on_candle(candle(open: 98, high: 100.04, low: 97, close: 98.5))
        engine.on_candle(candle(open: 98, high: 99,     low: 96, close: 97))
        engine.on_candle(candle(open: 97, high: 98,     low: 95, close: 96))
      end

      it "merges them into a single buy-side liquidity level" do
        buy_pools = emitted_pools.select(&:buy_side?)
        expect(buy_pools.size).to eq 1
        expect(buy_pools.first.level).to be_within(0.1).of(100)
      end
    end

    context "when highs sit further apart than ATR tolerance" do
      before do
        engine.on_candle(candle(open: 97, high: 100, low: 96, close: 98))
        engine.on_candle(candle(open: 98, high: 102, low: 97, close: 99))
        engine.on_candle(candle(open: 99, high: 100, low: 97, close: 98))
        engine.on_candle(candle(open: 98, high: 99,  low: 96, close: 97))
      end

      it "preserves them as distinct buy-side liquidity levels" do
        levels   = emitted_pools.select(&:buy_side?).map(&:level)
        near_100 = levels.any? { |l| (l - 100).abs <= 0.5 }
        near_102 = levels.any? { |l| (l - 102).abs <= 0.5 }

        expect(near_100).to be(true), "expected a buy-side pool near 100, got #{levels.inspect}"
        expect(near_102).to be(true), "expected a buy-side pool near 102, got #{levels.inspect}"
      end
    end
  end
end

RSpec.describe "liquidity sweep classification", :liquidity do
  context "during bearish reversal conditions" do
    context "when buy-side liquidity is pierced and price rejects below" do
      include_context "equal_highs_present"
      before { engine.on_candle(sweep_above(level: 100, wick: 1.5, rejection_close: 98.5)) }

      it "fires a buy-side sweep event" do
        expect(emitted_events[:sweep]).to contain_buy_side_sweep
      end
    end

    context "when a high-momentum candle blasts through resting liquidity" do
      include_context "equal_highs_present"
      let(:liquidity_level) { 200 }

      before do
        engine.on_candle(candle(open: 199, high: 204, low: 195, close: 196, volume: 10_000))
      end

      it "classifies the sweep velocity as aggressive" do
        expect(emitted_events[:sweep]).to contain_aggressive_sweep
      end
    end

    context "when a sweep is followed by bearish displacement" do
      include_context "equal_highs_present"

      before do
        engine.on_candle(sweep_above(level: 100, wick: 1.0, rejection_close: 99))
        engine.on_candle(displacement_down(close: 96, size: 4.0))
      end

      it "produces a buy-side sweep event" do
        expect(emitted_events[:sweep]).to contain_buy_side_sweep
      end

      it "produces a bearish displacement event" do
        expect(emitted_events[:displacement]).to have_displacement(:bearish)
      end
    end
  end

  context "under invalid sweep conditions" do
    context "when the candle closes above the level (continuation, not rejection)" do
      include_context "equal_highs_present"
      before { engine.on_candle(candle(open: 99, high: 102, low: 98.5, close: 101.5)) }

      it "does not classify the candle as a buy-side sweep" do
        non_reclaim = emitted_events[:sweep].reject(&:reclaimed?)
        expect(non_reclaim.select(&:buy_side?)).to be_empty
      end
    end

    context "when price reclaims the swept level on the next candle" do
      include_context "equal_highs_present"

      before do
        engine.on_candle(sweep_above(level: 100, wick: 0.5, rejection_close: 99.5))
        engine.on_candle(candle(open: 99.5, high: 102, low: 99, close: 101.5))
      end

      it "emits a follow-up reclaim event invalidating the sweep" do
        expect(emitted_events[:sweep]).to contain_reclaimed_sweep
      end
    end
  end
end
