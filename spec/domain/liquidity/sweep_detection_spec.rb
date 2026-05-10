RSpec.describe "Liquidity sweep detection" do
  context "during bearish reversal conditions" do
    context "when buyside liquidity is swept and price rejects" do
      include_context "equal_highs_present"

      before do
        engine.on_candle(sweep_above(level: liquidity_level, wick: 1.5,
                                     rejection_close: liquidity_level - 1.5))
      end

      it "fires a buy-side sweep against the resting pool" do
        expect(emitted_events[:sweep]).to contain_buy_side_sweep
      end

      it "records a sweep against the resting equal-highs level" do
        at_level = emitted_events[:sweep].select { |s| s.buy_side? && (s.swept_level - liquidity_level).abs <= 0.5 }
        expect(at_level).not_to be_empty,
          "expected a buy-side sweep near #{liquidity_level}, got levels: #{emitted_events[:sweep].map(&:swept_level).inspect}"
      end
    end

    context "when displacement follows the sweep" do
      include_context "liquidity_sweep_confirmed"

      before do
        engine.on_candle(displacement_down(close: liquidity_level - 5,
                                           size: 5.0, volume: 10_000))
      end

      it "confirms bearish displacement aligned with the swept side" do
        expect(emitted_events[:displacement]).to have_displacement(:bearish)
      end
    end
  end

  context "during bullish reversal conditions" do
    context "when sellside liquidity is swept and price rejects" do
      include_context "equal_lows_present"

      before do
        engine.on_candle(sweep_below(level: liquidity_level, wick: 1.5,
                                     rejection_close: liquidity_level + 1.5))
      end

      it "fires a sell-side sweep against the resting pool" do
        expect(emitted_events[:sweep]).to contain_sell_side_sweep
      end
    end
  end

  context "under invalid sweep conditions" do
    context "when price closes through equal highs (acceptance, not sweep)" do
      include_context "equal_highs_present"

      before do
        engine.on_candle(candle(open: 99, high: 102, low: 98.5, close: 101.5))
      end

      it "ignores shallow continuation as a sweep" do
        non_reclaim = emitted_events[:sweep].reject(&:reclaimed?).select(&:buy_side?)
        expect(non_reclaim).to be_empty
      end
    end

    context "when the sweep is reclaimed by the next candle" do
      include_context "equal_highs_present"

      before do
        engine.on_candle(sweep_above(level: liquidity_level, wick: 0.5,
                                     rejection_close: liquidity_level - 0.5))
        engine.on_candle(candle(open: liquidity_level - 0.5, high: liquidity_level + 2,
                                low: liquidity_level - 1, close: liquidity_level + 1.5))
      end

      it "emits a follow-up reclaim event invalidating the sweep" do
        expect(emitted_events[:sweep]).to contain_reclaimed_sweep
      end
    end
  end

  context "execution invariants" do
    context "with aggressive displacement during the sweep" do
      include_context "equal_highs_present"
      let(:liquidity_level) { 200 }

      before do
        engine.on_candle(candle(open: 199, high: 204, low: 195, close: 196,
                                volume: 10_000))
      end

      it "classifies the sweep as aggressive" do
        expect(emitted_events[:sweep]).to contain_aggressive_sweep
      end
    end
  end
end
