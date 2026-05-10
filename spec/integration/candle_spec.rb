RSpec.describe "candle value semantics", :integration do
  let(:bullish_candle) do
    SmartMoney::Candle.new(timestamp: Time.now, open: 100.0, high: 105.0,
                           low: 98.0,  close: 103.0, volume: 500)
  end
  let(:bearish_candle) do
    SmartMoney::Candle.new(timestamp: Time.now, open: 105.0, high: 106.0,
                           low: 99.0,  close: 101.0, volume: 100)
  end

  context "as an immutable trade record" do
    it "freezes itself after construction" do
      expect(bullish_candle).to be_frozen
    end

    it "exposes the open / high / low / close / volume of the period" do
      expect(bullish_candle.open).to   eq 100.0
      expect(bullish_candle.high).to   eq 105.0
      expect(bullish_candle.low).to    eq 98.0
      expect(bullish_candle.close).to  eq 103.0
      expect(bullish_candle.volume).to eq 500
    end

    it "compares equal to another candle with the same OHLCV and timestamp" do
      twin = SmartMoney::Candle.new(timestamp: bullish_candle.timestamp, open: 100.0, high: 105.0,
                                    low: 98.0, close: 103.0, volume: 500)
      expect(bullish_candle).to eq twin
    end
  end

  context "when the close finishes above the open" do
    it "classifies the candle as bullish" do
      expect(bullish_candle.bullish?).to be true
    end

    it "rejects the bearish classification" do
      expect(bullish_candle.bearish?).to be false
    end
  end

  context "when the close finishes below the open" do
    it "classifies the candle as bearish" do
      expect(bearish_candle.bearish?).to be true
    end

    it "rejects the bullish classification" do
      expect(bearish_candle.bullish?).to be false
    end
  end

  context "describing the body and wicks" do
    it "reports the body extremes from open and close" do
      expect(bullish_candle.body_high).to eq 103.0
      expect(bullish_candle.body_low).to  eq 100.0
    end

    it "reports the body size as the absolute open-close distance" do
      expect(bullish_candle.body_size).to eq 3.0
    end

    it "reports the full range as high minus low" do
      expect(bullish_candle.range).to eq 7.0
    end

    it "reports the wick lengths above and below the body" do
      expect(bullish_candle.upper_wick).to eq 2.0
      expect(bullish_candle.lower_wick).to eq 2.0
    end
  end
end
