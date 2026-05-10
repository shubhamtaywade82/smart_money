RSpec.describe SmartMoney::Structure::TrendState do
  subject(:state) { described_class.new }

  let(:pivot) { SmartMoney::Swings::PivotDetector::Pivot.new(direction: :high, level: 105.0, index: 10, timestamp: Time.now) }
  let(:low_pivot) { SmartMoney::Swings::PivotDetector::Pivot.new(direction: :low, level: 95.0, index: 20, timestamp: Time.now) }

  it "starts in :ranging state" do
    expect(state.state).to eq :ranging
    expect(state.established?).to be false
  end

  describe "#on_bullish_bos" do
    it "transitions to :bullish after first bullish BOS" do
      state.on_bullish_bos(pivot)
      expect(state.bullish?).to be true
      expect(state.established?).to be true
    end

    it "stores last_hh" do
      state.on_bullish_bos(pivot)
      expect(state.last_hh).to eq pivot
    end

    it "resets bearish_bos_count" do
      state.on_bearish_bos(low_pivot)
      state.on_bullish_bos(pivot)
      expect(state.bearish_bos_count).to eq 0
    end
  end

  describe "#on_bearish_bos" do
    it "transitions to :bearish after first bearish BOS" do
      state.on_bearish_bos(low_pivot)
      expect(state.bearish?).to be true
    end

    it "stores last_ll" do
      state.on_bearish_bos(low_pivot)
      expect(state.last_ll).to eq low_pivot
    end
  end

  describe "state transitions" do
    it "switches from bullish to bearish via on_bearish_bos" do
      state.on_bullish_bos(pivot)
      expect(state.bullish?).to be true
      state.on_bearish_bos(low_pivot)
      expect(state.bearish?).to be true
    end
  end
end
