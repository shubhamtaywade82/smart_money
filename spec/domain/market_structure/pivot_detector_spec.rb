RSpec.describe "swing pivot confirmation", :market_structure do
  subject(:detector) { SmartMoney::Swings::PivotDetector.new(left: 2, right: 2) }

  let(:series) { SmartMoney::CandleSeries.new(capacity: 50) }

  def push_candles(highs_lows)
    highs_lows.each.with_index do |(h, l), i|
      series << candle(open: (h + l) / 2.0, high: h, low: l, close: (h + l) / 2.0,
                       timestamp: Time.at(i * 300))
    end
  end

  context "during a clean rally followed by reversal" do
    context "when the center bar's high exceeds both neighbours" do
      it "confirms the center bar as a swing high" do
        push_candles([[100, 98], [102, 100], [105, 103], [103, 101], [101, 99]])
        pivot = detector.detect(series, 5)

        expect(pivot.direction).to eq :high
        expect(pivot.level).to     eq 105
      end
    end
  end

  context "during a clean drop followed by recovery" do
    context "when the center bar's low is lower than both neighbours" do
      it "confirms the center bar as a swing low" do
        push_candles([[102, 100], [101, 99], [100, 96], [101, 99], [102, 100]])
        pivot = detector.detect(series, 5)

        expect(pivot.direction).to eq :low
        expect(pivot.level).to     eq 96
      end
    end
  end

  context "before the right-side confirmation window has filled" do
    it "withholds emission until enough bars have arrived" do
      series << candle(open: 100, high: 102, low: 99, close: 101)
      expect(detector.detect(series, 1)).to be_nil
    end
  end

  context "during a monotonically rising series" do
    it "produces no pivot because no bar is locally extreme" do
      push_candles([[100, 99], [101, 100], [102, 101], [103, 102], [104, 103]])
      expect(detector.detect(series, 5)).to be_nil
    end
  end

  context "when neighbouring bars share the same high" do
    it "rejects the candidate as a swing high under strict greater-than confirmation" do
      push_candles([[100, 98], [105, 103], [105, 103], [104, 102], [103, 101]])
      pivot = detector.detect(series, 5)

      expect(pivot&.direction).not_to eq(:high)
    end
  end
end
