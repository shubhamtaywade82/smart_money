RSpec.describe "swing pivot emission", :market_structure, :scenario do
  context "during a clean bullish-then-bearish reversal" do
    context "when sufficient right-side candles confirm the peak" do
      scenario "emits a confirmed swing high above the trend's prior highs" do
        given_market do
          bullish_trend(from: 100, to: 110, steps: 5)
        end

        when_candles_processed do
          candle(open: 111,   high: 115, low: 110, close: 112)
          candle(open: 112,   high: 113, low: 109, close: 110)
          candle(open: 110,   high: 111, low: 108, close: 109)
          candle(open: 109,   high: 110, low: 107, close: 108)
          candle(open: 108,   high: 109, low: 106, close: 107)
          candle(open: 107,   high: 108, low: 105, close: 106)
        end

        then_expect do
          highs = events(:swing).select(&:high?)
          expect(highs.last&.level).to be > 110
        end
      end
    end
  end

  context "during a continuous monotonic uptrend" do
    scenario "produces no swing high because no bar is locally extreme" do
      when_candles_processed do
        candle(open: 100, high: 101, low: 99,  close: 100.8)
        candle(open: 101, high: 102, low: 100, close: 101.8)
        candle(open: 102, high: 103, low: 101, close: 102.8)
        candle(open: 103, high: 104, low: 102, close: 103.8)
        candle(open: 104, high: 105, low: 103, close: 104.8)
      end

      then_expect do
        expect(events(:swing).select(&:high?)).to be_empty
      end
    end
  end

  context "during a strong impulsive bullish leg" do
    scenario "ignores insignificant micro-pullbacks as swing lows" do
      given_market do
        bullish_trend(from: 100, to: 120, steps: 10)
      end

      when_candles_processed do
        candle(open: 121,   high: 122, low: 120.8, close: 121.5)
        candle(open: 121.5, high: 123, low: 121,   close: 122.5)
        candle(open: 122.5, high: 124, low: 122,   close: 123.5)
      end

      then_expect do
        lows_in_range = events(:swing).select { |e| e.low? && e.level.between?(120, 122) }
        expect(lows_in_range).to be_empty
      end
    end
  end

  context "when adjacent candles share the same high" do
    scenario "groups them into a single liquidity cluster rather than emitting twice" do
      when_candles_processed do
        candle(open: 98, high: 100,   low: 97, close: 99)
        candle(open: 99, high: 100,   low: 98, close: 99.2)
        candle(open: 99, high: 99.5,  low: 97, close: 98)
        candle(open: 98, high: 98.5,  low: 96, close: 97)
        candle(open: 97, high: 97.5,  low: 95, close: 96)
      end

      then_expect do
        external_highs_at_100 = events(:swing).select { |e| e.high? && e.level.round == 100 && e.external? }
        expect(external_highs_at_100.size).to be <= 1
      end
    end
  end

  context "timestamping pivots" do
    scenario "stamps the swing event with the pivot candle's time, not the confirmation candle's time" do
      when_candles_processed do
        candle(open: 103, high: 104,   low: 100,    close: 101,   timestamp: Time.at(1_000))
        candle(open: 101, high: 102,   low: 98,     close: 99,    timestamp: Time.at(1_300))
        candle(open: 99,  high: 101,   low: 98.5,   close: 100,   timestamp: Time.at(1_600))
        candle(open: 100, high: 102,   low: 99,     close: 101,   timestamp: Time.at(1_900))
        candle(open: 101, high: 103,   low: 100,    close: 102,   timestamp: Time.at(2_200))
      end

      then_expect do
        lows = events(:swing).select(&:low?)
        next if lows.empty?

        expect(lows.last.timestamp).to eq Time.at(1_300)
      end
    end
  end
end

RSpec.describe "adaptive ATR window", :market_structure do
  context "comparing low- and high-volatility regimes" do
    it "produces a larger ATR when range expansion dominates the recent stream" do
      low_vol = SmartMoney::Swings::AdaptiveSwingEngine.new(atr_period: 14, swing_lookback: 2)
      30.times do |i|
        low_vol.process(candle(open: 100 + i * 0.1, high: 100 + i * 0.1 + 0.15,
                               low: 100 + i * 0.1 - 0.05, close: 100 + i * 0.1 + 0.08,
                               timestamp: Time.at(1_700_000_000 + i * 300)))
      end

      high_vol = SmartMoney::Swings::AdaptiveSwingEngine.new(atr_period: 14, swing_lookback: :adaptive)
      30.times do |i|
        high_vol.process(candle(open: 100 + i * 2.0, high: 100 + i * 2.0 + 3.0,
                                low: 100 + i * 2.0 - 1.5, close: 100 + i * 2.0 + 1.5,
                                timestamp: Time.at(1_700_000_000 + i * 300)))
      end

      expect(high_vol.atr).to be > low_vol.atr
    end
  end

  context "instance isolation" do
    it "does not leak state between engines fed independently" do
      e1 = SmartMoney::Swings::AdaptiveSwingEngine.new
      e2 = SmartMoney::Swings::AdaptiveSwingEngine.new

      e1.process(candle(open: 100, high: 105, low: 99, close: 102))

      expect(e2.candle_count).to eq 0
      expect(e2.atr).to be_nil
    end
  end
end
