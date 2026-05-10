RSpec.describe "sweep + displacement confluence", :confluence do
  subject(:setups) { [] }

  let(:engine)     { SmartMoney::Engine.new }
  let!(:confluence) do
    SmartMoney::Strategy::ConfluenceEngine.new(engine: engine).tap do |c|
      c.subscribe { |e| setups << e }
    end
  end

  context "during bullish reversal conditions" do
    context "when sellside liquidity is swept and bullish displacement follows" do
      include_context "equal_lows_present"

      before do
        engine.on_candle(sweep_below(level: 100, wick: 1.5, rejection_close: 101.5))
        engine.on_candle(displacement_up(close: 107, size: 6.0, volume: 12_000))
      end

      it "publishes a long setup composed of sweep + displacement" do
        expect(setups.last).to be_valid_long_signal
      end

      it "carries the sell-side sweep as supporting evidence" do
        expect(setups.last.sweep.sell_side?).to be true
      end

      it "scores the setup above zero" do
        expect(setups.last).to have_score_above(0)
      end
    end
  end

  context "during bearish reversal conditions" do
    context "when buyside liquidity is swept and bearish displacement follows" do
      include_context "equal_highs_present"

      before do
        engine.on_candle(sweep_above(level: 100, wick: 1.5, rejection_close: 98.5))
        engine.on_candle(displacement_down(close: 93, size: 6.0, volume: 12_000))
      end

      it "publishes a short setup composed of sweep + displacement" do
        expect(setups.last).to be_valid_short_signal
      end
    end
  end

  context "under invalid market conditions" do
    context "when displacement does not arrive within the setup window" do
      include_context "equal_highs_present"

      before do
        # Small-body sweep at known index
        engine.on_candle(candle(open: 99.7, high: 100.3, low: 99.4, close: 99.6))
        # Beyond SETUP_WINDOW
        6.times { engine.on_candle(candle(open: 99.5, high: 99.8, low: 99.2, close: 99.5)) }
        engine.on_candle(displacement_down(close: 94, size: 5.0, volume: 8000))
      end

      it "drops the stale sweep from the matchable set" do
        stale = setups.select { |s| s.sweep.candle_index == 11 }
        expect(stale).to be_empty
      end
    end

    context "when the sweep is reclaimed before displacement" do
      include_context "equal_highs_present"

      before do
        engine.on_candle(sweep_above(level: 100, wick: 0.5, rejection_close: 99.5))
        engine.on_candle(candle(open: 99.5, high: 102, low: 99, close: 101.5)) # reclaim
        engine.on_candle(displacement_down(close: 96, size: 4.0, volume: 8000))
      end

      it "does not compose a setup from the reclaimed sweep" do
        from_reclaimed = setups.select { |s| s.sweep.swept_level.round == 100 }
        expect(from_reclaimed).to be_empty
      end
    end
  end

  context "execution invariants" do
    it "produces deterministic setups across identical replays" do
      run1 = []
      run2 = []

      [run1, run2].each do |bucket|
        e = SmartMoney::Engine.new
        SmartMoney::Strategy::ConfluenceEngine.new(engine: e).subscribe { |s| bucket << s }

        bull_sequence(from: 95, step: 1, count: 5).each { |c| e.on_candle(c) }
        equal_high_pair(level: 100).each { |c| e.on_candle(c) }
        bear_sequence(from: 99.5, step: 0.5, count: 3).each { |c| e.on_candle(c) }
        e.on_candle(sweep_above(level: 100, wick: 1.5, rejection_close: 98.5))
        e.on_candle(displacement_down(close: 93, size: 6.0, volume: 12_000))
      end

      expect(run1).to match_replay(run2)
    end

    it "does not repaint published setups when more candles arrive" do
      bull_sequence(from: 95, step: 1, count: 5).each { |c| engine.on_candle(c) }
      equal_high_pair(level: 100).each { |c| engine.on_candle(c) }
      bear_sequence(from: 99.5, step: 0.5, count: 3).each { |c| engine.on_candle(c) }
      engine.on_candle(sweep_above(level: 100, wick: 1.5, rejection_close: 98.5))
      engine.on_candle(displacement_down(close: 93, size: 6.0, volume: 12_000))

      snapshot = setups.dup
      5.times { |i| engine.on_candle(candle(open: 92, high: 93, low: 91, close: 92)) }

      expect([snapshot, setups]).to not_repaint_structure
    end
  end
end
