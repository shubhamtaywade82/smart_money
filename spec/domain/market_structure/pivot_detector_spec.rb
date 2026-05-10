RSpec.describe SmartMoney::Swings::PivotDetector do
  subject(:detector) { described_class.new(left: 2, right: 2) }

  let(:series) { SmartMoney::CandleSeries.new(capacity: 50) }

  def push_candles(highs_lows)
    highs_lows.each.with_index do |(h, l), i|
      series << candle(open: (h + l) / 2.0, high: h, low: l, close: (h + l) / 2.0,
                       timestamp: Time.at(i * 300))
    end
  end

  describe "pivot high detection" do
    it "detects a pivot high when center is higher than left and right bars" do
      # With left=2, right=2: candidate is at series[-3]; confirmed after right-side bars are seen.
      # After pushing 5 candles, candidate = candle[2] (high=105).
      push_candles([
        [100, 98], [102, 100], [105, 103], [103, 101], [101, 99]
      ])
      pivot = detector.detect(series, 5)
      expect(pivot).not_to be_nil
      expect(pivot.direction).to eq :high
      expect(pivot.level).to eq 105
    end

    it "returns nil when not enough bars" do
      series << candle(open: 100, high: 102, low: 99, close: 101)
      expect(detector.detect(series, 1)).to be_nil
    end
  end

  describe "pivot low detection" do
    it "detects a pivot low when center is lower than left and right bars" do
      # Pivot low at candle[2] (low=96), confirmed after pushing 5 candles.
      push_candles([
        [102, 100], [101, 99], [100, 96], [101, 99], [102, 100]
      ])
      pivot = detector.detect(series, 5)
      expect(pivot).not_to be_nil
      expect(pivot.direction).to eq :low
      expect(pivot.level).to eq 96
    end
  end

  describe "no pivot" do
    it "returns nil for a monotonically increasing series" do
      push_candles([
        [100, 99], [101, 100], [102, 101], [103, 102], [104, 103]
      ])
      pivot = detector.detect(series, 5)
      expect(pivot).to be_nil
    end
  end

  describe "equal highs" do
    it "does not detect pivot when a neighbor bar equals center high" do
      # candle[1] and candle[2] both have high=105 — strict `>` check rejects the pivot.
      push_candles([
        [100, 98], [105, 103], [105, 103], [104, 102], [103, 101]
      ])
      pivot = detector.detect(series, 5)
      expect(pivot&.direction).not_to eq(:high)
    end
  end
end
