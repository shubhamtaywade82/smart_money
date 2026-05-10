RSpec.describe "candle series ring buffer", :integration do
  let(:series) { SmartMoney::CandleSeries.new(capacity: 5) }
  let(:c1) { candle(open: 100,   high: 101, low: 99,    close: 100.5, timestamp: Time.at(1)) }
  let(:c2) { candle(open: 100.5, high: 102, low: 100,   close: 101,   timestamp: Time.at(2)) }
  let(:c3) { candle(open: 101,   high: 103, low: 100.5, close: 102,   timestamp: Time.at(3)) }
  let(:c4) { candle(open: 102,   high: 104, low: 101.5, close: 103,   timestamp: Time.at(4)) }
  let(:c5) { candle(open: 103,   high: 105, low: 102.5, close: 104,   timestamp: Time.at(5)) }
  let(:c6) { candle(open: 104,   high: 106, low: 103.5, close: 105,   timestamp: Time.at(6)) }

  context "as a streaming append-only buffer" do
    context "when a candle is appended" do
      it "grows the size by one" do
        series << c1
        expect(series.size).to eq 1
      end

      it "returns itself so the producer can chain appends" do
        expect(series << c1).to be series
      end
    end

    context "when capacity is exceeded" do
      it "evicts the oldest candle and retains the newest at the tail" do
        [c1, c2, c3, c4, c5, c6].each { |c| series << c }

        expect(series.size).to eq 5
        expect(series[-1]).to eq c6
        expect(series[0]).to  eq c2
      end
    end
  end

  context "indexed access for incremental engines" do
    before { [c1, c2, c3].each { |c| series << c } }

    context "when reading from the oldest end" do
      it "returns candles in arrival order under positive indices" do
        expect(series[0]).to eq c1
        expect(series[1]).to eq c2
        expect(series[2]).to eq c3
      end
    end

    context "when reading from the newest end" do
      it "returns the most recent candles under negative indices" do
        expect(series[-1]).to eq c3
        expect(series[-2]).to eq c2
        expect(series[-3]).to eq c1
      end
    end

    context "when the index is out of bounds" do
      it "returns nil rather than raising" do
        expect(series[5]).to be_nil
        expect(series[-6]).to be_nil
      end
    end
  end

  context "querying the trailing window" do
    before { [c1, c2, c3, c4].each { |c| series << c } }

    it "returns the last n candles in chronological order" do
      expect(series.last(2)).to eq [c3, c4]
    end

    it "clamps to the available size when n exceeds the buffer" do
      expect(series.last(10).size).to eq 4
    end

    it "returns a single-element array when called with no argument" do
      expect(series.last).to eq [c4]
    end
  end

  context "extreme-value queries used by indicators" do
    before { [c1, c2, c3, c4, c5].each { |c| series << c } }

    it "reports the highest high across all stored candles" do
      expect(series.highest_high).to eq 105
    end

    it "reports the highest high within the trailing n candles" do
      expect(series.highest_high(2)).to eq 105
    end

    it "reports the lowest low across all stored candles" do
      expect(series.lowest_low).to eq 99
    end

    it "reports the lowest low within the trailing n candles" do
      expect(series.lowest_low(1)).to eq 102.5
    end
  end

  context "lifecycle predicates" do
    it "reports empty before any candle is appended" do
      expect(series.empty?).to be true
    end

    it "reports not full while size is below capacity" do
      series << c1
      expect(series.full?).to be false
    end

    it "reports full once size matches capacity" do
      [c1, c2, c3, c4, c5].each { |c| series << c }
      expect(series.full?).to be true
    end
  end

  context "Enumerable iteration" do
    before { [c1, c2, c3].each { |c| series << c } }

    it "yields candles oldest-first under each" do
      collected = []
      series.each { |c| collected << c }
      expect(collected).to eq [c1, c2, c3]
    end

    it "supports Enumerable transforms such as map" do
      expect(series.map(&:close)).to eq [100.5, 101, 102]
    end
  end

  context "default capacity" do
    it "honors the configured default series capacity" do
      SmartMoney.configure { |c| c.default_series_capacity = 10 }
      expect(SmartMoney::CandleSeries.new.capacity).to eq 10
    end
  end
end
