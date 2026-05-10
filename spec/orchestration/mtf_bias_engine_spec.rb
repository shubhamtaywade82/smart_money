RSpec.describe SmartMoney::MultiTimeframe::BiasEngine do
  subject(:bias) { described_class.new(htf_timeframe: "1h", ltf_timeframe: "5m") }

  describe "isolated state per timeframe" do
    it "tracks HTF and LTF trend states independently" do
      htf_bull = bull_sequence(from: 100, step: 2, count: 8)
      ltf_bear = bear_sequence(from: 110, step: 1, count: 8)

      htf_bull.each { |c| bias.on_htf_candle(c) }
      ltf_bear.each { |c| bias.on_ltf_candle(c) }

      expect(bias.htf.candle_count).to eq 8
      expect(bias.ltf.candle_count).to eq 8
    end
  end

  describe "alignment queries" do
    it "reports aligned_long when HTF state is bullish" do
      bias.htf.trend_state.on_bullish_bos(double(level: 100, index: 1))

      expect(bias.aligned_long?).to be true
      expect(bias.aligned_short?).to be false
      expect(bias.aligned_with?(:long)).to be true
      expect(bias.aligned_with?(:bullish)).to be true
    end

    it "reports aligned_short when HTF state is bearish" do
      bias.htf.trend_state.on_bearish_bos(double(level: 100, index: 1))

      expect(bias.aligned_short?).to be true
      expect(bias.aligned_long?).to be false
      expect(bias.aligned_with?(:short)).to be true
    end

    it "reports neither alignment while ranging" do
      expect(bias.aligned_long?).to be false
      expect(bias.aligned_short?).to be false
    end
  end

  describe "HTF bias drives LTF trade decisions" do
    it "agrees with LTF bullish setup only when HTF trend is bullish" do
      bias.htf.trend_state.on_bullish_bos(double(level: 100, index: 1))
      bias.ltf.trend_state.on_bullish_bos(double(level: 100, index: 1))

      expect(bias.htf_bias).to eq :bullish
      expect(bias.ltf_state).to eq :bullish
      expect(bias.aligned_long?).to be true
    end
  end
end
