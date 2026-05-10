RSpec.describe "liquidity sweep reversal playbook", :system, :scenario do
  context "during bearish reversal conditions" do
    context "when buy-side liquidity is swept and bearish displacement follows" do
      scenario "produces a buy-side sweep with bearish displacement confirmation" do
        given_market do
          equal_highs(at: 100)
        end

        when_candles_processed do
          sweep_above(level: 100, wick: 2.0, rejection_close: 98)
          displacement_down(close: 93, size: 7.0, volume: 12_000)
        end

        then_expect do
          liquidity_to_be_swept(:buy_side)
          displacement_to_be_bearish
        end
      end
    end
  end

  context "during bullish reversal conditions" do
    context "when sell-side liquidity is swept and bullish displacement follows" do
      scenario "produces a sell-side sweep with bullish displacement confirmation" do
        given_market do
          equal_lows(at: 95)
        end

        when_candles_processed do
          sweep_below(level: 95, wick: 2.0, rejection_close: 97)
          displacement_up(close: 104, size: 7.0, volume: 12_000)
        end

        then_expect do
          liquidity_to_be_swept(:sell_side)
          displacement_to_be_bullish
        end
      end
    end
  end

  context "under invalid reversal conditions" do
    context "when price breaks equal highs with body acceptance instead of rejection" do
      scenario "rejects the setup as a continuation rather than a sweep" do
        given_market do
          equal_highs(at: 100)
        end

        when_candles_processed do
          candle(open: 99,    high: 102, low: 98.5, close: 101.5)
          candle(open: 101.5, high: 103, low: 101,  close: 102.5)
        end

        then_expect do
          sweeps = events(:sweep).reject(&:reclaimed?).select(&:buy_side?)
          expect(sweeps).to be_empty
        end
      end
    end
  end
end

RSpec.describe "structural BOS playbook", :system, :scenario do
  context "during bullish trend continuation" do
    context "when price pulls back and closes above the prior swing high" do
      scenario "confirms a bullish break of structure and flips the trend bullish" do
        given_market do
          bullish_trend(from: 100, to: 115, steps: 10)
        end

        when_candles_processed do
          candle(open: 115, high: 116, low: 112,  close: 113)
          candle(open: 113, high: 114, low: 111,  close: 112)
          candle(open: 112, high: 120, low: 111.5, close: 119)
        end

        then_expect do
          structure_to_shift(:bullish)
          trend_to_be(:bullish)
        end
      end
    end
  end

  context "during a completed bullish-to-bearish reversal" do
    context "when a higher-low is broken after a confirmed bullish trend" do
      scenario "confirms a bearish change of character" do
        when_candles_processed do
          candle(open: 102, high: 104,   low: 101,  close: 103, timestamp: Time.at(1_000))
          candle(open: 103, high: 103.5, low: 100,  close: 101, timestamp: Time.at(1_300))
          candle(open: 101, high: 101.5, low: 98,   close: 99,  timestamp: Time.at(1_600))
          candle(open: 99,  high: 104,   low: 100,  close: 103, timestamp: Time.at(1_900))
          candle(open: 103, high: 106,   low: 103,  close: 105, timestamp: Time.at(2_200))
          candle(open: 105, high: 107,   low: 104.5, close: 106, timestamp: Time.at(2_500))
          candle(open: 106, high: 110,   low: 105,  close: 109, timestamp: Time.at(2_800))
          candle(open: 109, high: 108.5, low: 104,  close: 105, timestamp: Time.at(3_100))
          candle(open: 105, high: 107,   low: 103,  close: 105, timestamp: Time.at(3_400))
          candle(open: 106, high: 114,   low: 105,  close: 113, timestamp: Time.at(3_700))
          candle(open: 102, high: 103,   low: 94,   close: 95,  timestamp: Time.at(4_000))
        end

        then_expect do
          expect(events(:choch)).to confirm_bearish_choch
        end
      end
    end
  end
end

RSpec.describe "engine throughput budget", :system do
  context "when feeding a 500-candle synthetic stream" do
    it "completes in well under the 50ms processing budget" do
      engine  = SmartMoney::Engine.new
      ts      = Time.at(1_700_000_000)
      candles = 500.times.map do |i|
        candle(open:  100 + Math.sin(i * 0.05) * 10,
               high:  100 + Math.sin(i * 0.05) * 10 + 1.5,
               low:   100 + Math.sin(i * 0.05) * 10 - 1.5,
               close: 100 + Math.sin(i * 0.05) * 10 + 0.5,
               timestamp: Time.at(ts.to_i + i * 300))
      end

      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      candles.each { |c| engine.on_candle(c) }
      elapsed_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000

      expect(elapsed_ms).to be < 50,
        "Engine processed 500 candles in #{elapsed_ms.round(1)}ms — exceeds 50ms budget"
    end
  end
end
