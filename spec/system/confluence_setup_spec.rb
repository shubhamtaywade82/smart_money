# System Spec: Confluence-Driven Setup
#
# A complete institutional setup, expressed as an executable trading
# playbook. Composed entirely from shared contexts + domain matchers — the
# example bodies focus on intent, not on candle plumbing.

RSpec.describe "Sweep-then-displacement reversal setup" do
  let(:engine) { SmartMoney::Engine.new }
  let(:setups) { [] }
  let(:engine_events) { Hash.new { |h, k| h[k] = [] } }

  let!(:confluence) do
    SmartMoney::Strategy::ConfluenceEngine.new(engine: engine).tap do |c|
      c.subscribe { |e| setups << e }
    end
  end

  before do
    SmartMoney::Engine::VALID_EVENTS.each do |type|
      engine.subscribe(type) { |e| engine_events[type] << e }
    end
  end

  context "during bearish reversal conditions" do
    context "when buyside liquidity is swept and bearish displacement follows" do
      include_context "equal_highs_present"

      before do
        engine.on_candle(sweep_above(level: 100, wick: 1.5, rejection_close: 98.5))
        engine.on_candle(displacement_down(close: 93, size: 6.0, volume: 12_000))
      end

      it "registers buy-side liquidity at the equal highs" do
        expect(engine_events[:liquidity_pool]).to contain_buy_side_pool(near: 100)
      end

      it "fires a buy-side sweep when price pierces and rejects" do
        expect(engine_events[:sweep]).to contain_buy_side_sweep
      end

      it "confirms bearish displacement after the sweep" do
        expect(engine_events[:displacement]).to have_displacement(:bearish)
      end

      it "publishes a valid short setup combining the sweep and the displacement" do
        expect(setups.last).to be_valid_short_signal
      end

      it "scores the setup above zero" do
        expect(setups.last).to have_score_above(0)
      end
    end
  end

  context "during bullish reversal conditions" do
    context "when sellside liquidity is swept and bullish displacement follows" do
      include_context "equal_lows_present"

      before do
        engine.on_candle(sweep_below(level: 100, wick: 1.5, rejection_close: 101.5))
        engine.on_candle(displacement_up(close: 107, size: 6.0, volume: 12_000))
      end

      it "registers sell-side liquidity at the equal lows" do
        expect(engine_events[:liquidity_pool]).to contain_sell_side_pool(near: 100)
      end

      it "fires a sell-side sweep" do
        expect(engine_events[:sweep]).to contain_sell_side_sweep
      end

      it "publishes a valid long setup" do
        expect(setups.last).to be_valid_long_signal
      end
    end
  end

  context "under invalid market conditions" do
    context "when price closes through liquidity (continuation, not sweep)" do
      include_context "equal_highs_present"

      before do
        engine.on_candle(candle(open: 99, high: 102, low: 98.5, close: 101.5))
      end

      it "does not register a fresh buy-side sweep" do
        non_reclaim_sweeps = engine_events[:sweep].reject(&:reclaimed?)
        expect(non_reclaim_sweeps.select(&:buy_side?)).to be_empty
      end

      it "does not publish a setup" do
        expect(setups).to be_empty
      end
    end
  end
end
