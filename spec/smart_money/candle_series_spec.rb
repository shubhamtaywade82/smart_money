RSpec.describe SmartMoney::CandleSeries do
  subject(:series) { described_class.new(capacity: 5) }

  let(:c1) { candle(open: 100, high: 101, low: 99, close: 100.5, timestamp: Time.at(1)) }
  let(:c2) { candle(open: 100.5, high: 102, low: 100, close: 101, timestamp: Time.at(2)) }
  let(:c3) { candle(open: 101, high: 103, low: 100.5, close: 102, timestamp: Time.at(3)) }
  let(:c4) { candle(open: 102, high: 104, low: 101.5, close: 103, timestamp: Time.at(4)) }
  let(:c5) { candle(open: 103, high: 105, low: 102.5, close: 104, timestamp: Time.at(5)) }
  let(:c6) { candle(open: 104, high: 106, low: 103.5, close: 105, timestamp: Time.at(6)) }

  describe "#append / <<" do
    it "increases size" do
      series << c1
      expect(series.size).to eq 1
    end

    it "returns self for chaining" do
      expect(series << c1).to be series
    end
  end

  describe "#[]" do
    before { [c1, c2, c3].each { |c| series << c } }

    it "supports positive indexing from oldest" do
      expect(series[0]).to eq c1
      expect(series[1]).to eq c2
      expect(series[2]).to eq c3
    end

    it "supports negative indexing from newest" do
      expect(series[-1]).to eq c3
      expect(series[-2]).to eq c2
      expect(series[-3]).to eq c1
    end

    it "returns nil for out-of-bounds" do
      expect(series[5]).to be_nil
      expect(series[-6]).to be_nil
    end
  end

  describe "ring buffer wrap-around" do
    it "evicts oldest element when capacity is exceeded" do
      [c1, c2, c3, c4, c5, c6].each { |c| series << c }
      expect(series.size).to eq 5
      expect(series[-1]).to eq c6
      expect(series[0]).to  eq c2
    end
  end

  describe "#last" do
    before { [c1, c2, c3, c4].each { |c| series << c } }

    it "returns the last n candles newest-last" do
      expect(series.last(2)).to eq [c3, c4]
    end

    it "clamps to available size" do
      expect(series.last(10).size).to eq 4
    end

    it "returns single-element array by default" do
      expect(series.last).to eq [c4]
    end
  end

  describe "#highest_high" do
    before { [c1, c2, c3, c4, c5].each { |c| series << c } }

    it "returns highest high across all candles" do
      expect(series.highest_high).to eq 105
    end

    it "returns highest high across last n candles" do
      expect(series.highest_high(2)).to eq 105
    end
  end

  describe "#lowest_low" do
    before { [c1, c2, c3, c4, c5].each { |c| series << c } }

    it "returns lowest low across all candles" do
      expect(series.lowest_low).to eq 99
    end

    it "returns lowest low across last n candles" do
      expect(series.lowest_low(1)).to eq 102.5
    end
  end

  describe "#full?" do
    it "returns false when not full" do
      series << c1
      expect(series.full?).to be false
    end

    it "returns true when at capacity" do
      [c1, c2, c3, c4, c5].each { |c| series << c }
      expect(series.full?).to be true
    end
  end

  describe "#empty?" do
    it "returns true when empty" do
      expect(series.empty?).to be true
    end
  end

  describe "Enumerable" do
    before { [c1, c2, c3].each { |c| series << c } }

    it "supports each" do
      collected = []
      series.each { |c| collected << c }
      expect(collected).to eq [c1, c2, c3]
    end

    it "supports map" do
      expect(series.map(&:close)).to eq [100.5, 101, 102]
    end
  end

  describe "with default capacity" do
    it "uses configuration default" do
      SmartMoney.configure { |c| c.default_series_capacity = 10 }
      s = described_class.new
      expect(s.capacity).to eq 10
    end
  end
end
