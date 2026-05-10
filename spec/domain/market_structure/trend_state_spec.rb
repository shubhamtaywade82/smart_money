RSpec.describe "market structure trend state", :market_structure do
  subject(:state) { SmartMoney::Structure::TrendState.new }

  let(:high_pivot) { SmartMoney::Swings::PivotDetector::Pivot.new(direction: :high, level: 105.0, index: 10, timestamp: Time.now) }
  let(:low_pivot)  { SmartMoney::Swings::PivotDetector::Pivot.new(direction: :low,  level:  95.0, index: 20, timestamp: Time.now) }

  context "before any structural event" do
    it "starts in a ranging state with no established direction" do
      expect(state.state).to eq :ranging
      expect(state.established?).to be false
    end
  end

  context "when a bullish break of structure occurs" do
    it "transitions to a bullish trend" do
      state.on_bullish_bos(high_pivot)
      expect(state.bullish?).to be true
      expect(state.established?).to be true
    end

    it "records the broken swing high as the latest higher high" do
      state.on_bullish_bos(high_pivot)
      expect(state.last_hh).to eq high_pivot
    end

    it "resets the prior bearish counter so the trend cleanly flips" do
      state.on_bearish_bos(low_pivot)
      state.on_bullish_bos(high_pivot)
      expect(state.bearish_bos_count).to eq 0
    end
  end

  context "when a bearish break of structure occurs" do
    it "transitions to a bearish trend" do
      state.on_bearish_bos(low_pivot)
      expect(state.bearish?).to be true
    end

    it "records the broken swing low as the latest lower low" do
      state.on_bearish_bos(low_pivot)
      expect(state.last_ll).to eq low_pivot
    end
  end

  context "during a full trend reversal" do
    it "switches from bullish to bearish on a bearish BOS" do
      state.on_bullish_bos(high_pivot)
      expect(state.bullish?).to be true

      state.on_bearish_bos(low_pivot)
      expect(state.bearish?).to be true
    end
  end
end
