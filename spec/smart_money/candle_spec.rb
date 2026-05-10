RSpec.describe SmartMoney::Candle do
  subject(:c) { described_class.new(timestamp: Time.now, open: 100.0, high: 105.0, low: 98.0, close: 103.0, volume: 500) }

  it "is frozen" do
    expect(c).to be_frozen
  end

  it "exposes OHLCV attributes" do
    expect(c.open).to   eq 100.0
    expect(c.high).to   eq 105.0
    expect(c.low).to    eq 98.0
    expect(c.close).to  eq 103.0
    expect(c.volume).to eq 500
  end

  describe "#bullish?" do
    it "returns true when close > open" do
      expect(c.bullish?).to be true
    end

    it "returns false when close < open" do
      bearish = described_class.new(timestamp: Time.now, open: 105.0, high: 106.0, low: 99.0, close: 101.0, volume: 100)
      expect(bearish.bullish?).to be false
    end
  end

  describe "#bearish?" do
    it "returns true when close < open" do
      bearish = described_class.new(timestamp: Time.now, open: 105.0, high: 106.0, low: 99.0, close: 101.0, volume: 100)
      expect(bearish.bearish?).to be true
    end
  end

  describe "#body_high" do
    it "returns max of open and close" do
      expect(c.body_high).to eq 103.0
    end
  end

  describe "#body_low" do
    it "returns min of open and close" do
      expect(c.body_low).to eq 100.0
    end
  end

  describe "#body_size" do
    it "returns absolute difference of open and close" do
      expect(c.body_size).to eq 3.0
    end
  end

  describe "#range" do
    it "returns high - low" do
      expect(c.range).to eq 7.0
    end
  end

  describe "#upper_wick" do
    it "returns high - body_high" do
      expect(c.upper_wick).to eq 2.0
    end
  end

  describe "#lower_wick" do
    it "returns body_low - low" do
      expect(c.lower_wick).to eq 2.0
    end
  end

  it "supports value equality" do
    c2 = described_class.new(timestamp: c.timestamp, open: 100.0, high: 105.0, low: 98.0, close: 103.0, volume: 500)
    expect(c).to eq c2
  end
end
