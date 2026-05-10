RSpec.describe "multi-timeframe bias orchestration", :multi_timeframe do
  subject(:bias) { SmartMoney::MultiTimeframe::BiasEngine.new(htf_timeframe: "1h", ltf_timeframe: "5m") }

  context "isolated state across timeframes" do
    it "advances HTF and LTF candle counts independently" do
      bull_sequence(from: 100, step: 2, count: 8).each { |c| bias.on_htf_candle(c) }
      bear_sequence(from: 110, step: 1, count: 8).each { |c| bias.on_ltf_candle(c) }

      expect(bias.htf.candle_count).to eq 8
      expect(bias.ltf.candle_count).to eq 8
    end
  end

  context "during HTF bullish conditions" do
    before { bias.htf.trend_state.on_bullish_bos(double(level: 100, index: 1)) }

    it "reports long alignment for the strategy layer" do
      expect(bias.aligned_long?).to be true
    end

    it "rejects short alignment" do
      expect(bias.aligned_short?).to be false
    end

    it "answers aligned_with for both :long and :bullish" do
      expect(bias.aligned_with?(:long)).to    be true
      expect(bias.aligned_with?(:bullish)).to be true
    end
  end

  context "during HTF bearish conditions" do
    before { bias.htf.trend_state.on_bearish_bos(double(level: 100, index: 1)) }

    it "reports short alignment for the strategy layer" do
      expect(bias.aligned_short?).to be true
    end

    it "rejects long alignment" do
      expect(bias.aligned_long?).to be false
    end

    it "answers aligned_with for :short" do
      expect(bias.aligned_with?(:short)).to be true
    end
  end

  context "while no HTF structure has formed" do
    it "reports neither long nor short alignment" do
      expect(bias.aligned_long?).to be false
      expect(bias.aligned_short?).to be false
    end
  end

  context "when HTF and LTF agree on bullish bias" do
    it "exposes the agreement to consumers via htf_bias and ltf_state" do
      bias.htf.trend_state.on_bullish_bos(double(level: 100, index: 1))
      bias.ltf.trend_state.on_bullish_bos(double(level: 100, index: 1))

      expect(bias.htf_bias).to eq :bullish
      expect(bias.ltf_state).to eq :bullish
      expect(bias.aligned_long?).to be true
    end
  end
end
