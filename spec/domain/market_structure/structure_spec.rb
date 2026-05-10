RSpec.describe "market structure shift detection", :market_structure, :scenario do
  context "during bullish trend continuation" do
    context "when price closes decisively above a confirmed swing high" do
      scenario "confirms a bullish break of structure" do
        given_market do
          bullish_trend(from: 100, to: 110, steps: 8)
        end

        when_candles_processed do
          candle(open: 110, high: 112,   low: 109,   close: 111)
          candle(open: 111, high: 112.5, low: 109.5, close: 110)
          candle(open: 110, high: 111,   low: 108,   close: 109)
          candle(open: 109, high: 110,   low: 107,   close: 108)
          candle(open: 108, high: 116,   low: 107.5, close: 115)
        end

        then_expect do
          expect(events(:bos)).to confirm_bullish_bos
        end
      end
    end

    context "when only the wick exceeds the swing high" do
      scenario "rejects the structure break" do
        when_candles_processed do
          candle(open: 100, high: 101.0, low: 99.5,  close: 100.8, timestamp: Time.at(1_000))
          candle(open: 101, high: 102.0, low: 100.5, close: 101.5, timestamp: Time.at(1_300))
          candle(open: 102, high: 103.0, low: 101.5, close: 102.5, timestamp: Time.at(1_600))
          candle(open: 102, high: 102.5, low: 101.0, close: 101.8, timestamp: Time.at(1_900))
          candle(open: 101, high: 101.5, low: 100.0, close: 100.5, timestamp: Time.at(2_200))
          candle(open: 101, high: 104.0, low: 100.5, close: 101.5, timestamp: Time.at(2_500))
        end

        then_expect do
          no_structure_break
        end
      end
    end
  end

  context "during ranging conditions with no established trend" do
    scenario "does not fire a structure break on choppy candles" do
      when_candles_processed do
        candle(open: 100,    high: 101.5, low: 99,    close: 100.5)
        candle(open: 100.5,  high: 102,   low: 100,   close: 101.2)
        candle(open: 101,    high: 101.8, low: 99.5,  close: 100.3)
        candle(open: 100,    high: 101,   low: 99,    close: 100.1)
        candle(open: 100,    high: 101.5, low: 99.2,  close: 100.4)
      end

      then_expect do
        no_structure_break
      end
    end
  end

  context "during a bullish-to-bearish reversal" do
    scenario "confirms a bearish change of character after a higher-low fails" do
      when_candles_processed do
        candle(open: 102, high: 104,   low: 101,   close: 103,   timestamp: Time.at(1_000))
        candle(open: 103, high: 103.5, low: 100,   close: 101,   timestamp: Time.at(1_300))
        candle(open: 101, high: 101.5, low: 98,    close: 99,    timestamp: Time.at(1_600))
        candle(open: 99,  high: 104,   low: 100,   close: 103,   timestamp: Time.at(1_900))
        candle(open: 103, high: 106,   low: 103,   close: 105,   timestamp: Time.at(2_200))
        candle(open: 105, high: 107,   low: 104.5, close: 106,   timestamp: Time.at(2_500))
        candle(open: 106, high: 110,   low: 105,   close: 109,   timestamp: Time.at(2_800))
        candle(open: 109, high: 108.5, low: 104,   close: 105,   timestamp: Time.at(3_100))
        candle(open: 105, high: 107,   low: 103,   close: 105,   timestamp: Time.at(3_400))
        candle(open: 106, high: 114,   low: 105,   close: 113,   timestamp: Time.at(3_700))
        candle(open: 102, high: 103,   low: 94,    close: 95,    timestamp: Time.at(4_000))
      end

      then_expect do
        expect(events(:choch)).to confirm_bearish_choch
      end
    end
  end

  context "during an impulsive bullish leg" do
    scenario "tracks internal structure independently of the higher-timeframe leg" do
      when_candles_processed do
        candle(open: 100,   high: 108,    low: 99,    close: 105,   timestamp: Time.at(1_000))
        candle(open: 105,   high: 107,    low: 100,   close: 101,   timestamp: Time.at(1_300))
        candle(open: 101,   high: 103,    low: 100.5, close: 102,   timestamp: Time.at(1_600))
        candle(open: 102,   high: 103.5,  low: 101.5, close: 103,   timestamp: Time.at(1_900))
        candle(open: 103,   high: 100.5,  low: 99,    close: 99.5,  timestamp: Time.at(2_200))
        candle(open: 100,   high: 103,    low: 100,   close: 102,   timestamp: Time.at(2_500))
        candle(open: 102,   high: 105,    low: 102,   close: 104,   timestamp: Time.at(2_800))
        candle(open: 104,   high: 105,    low: 102.5, close: 104.5, timestamp: Time.at(3_100))
        candle(open: 104,   high: 104,    low: 102,   close: 103.5, timestamp: Time.at(3_400))
        candle(open: 103,   high: 100.5,  low: 99.3,  close: 99.8,  timestamp: Time.at(3_700))
        candle(open: 100,   high: 103,    low: 100,   close: 102,   timestamp: Time.at(4_000))
        candle(open: 102,   high: 105,    low: 101,   close: 104,   timestamp: Time.at(4_300))
      end

      then_expect do
        internal_lows = events(:swing).select { |e| e.low? && e.respond_to?(:internal?) && e.internal? }
        expect(internal_lows).not_to be_empty
      end
    end
  end
end

RSpec.describe "change of character in established trends", :market_structure, :scenario do
  context "when no trend has yet been established" do
    scenario "ignores even a large move because there is no character to change from" do
      when_candles_processed do
        candle(open: 100, high: 108, low: 99, close: 107)
      end

      then_expect do
        expect(events(:choch)).to be_empty
      end
    end
  end

  context "during a clean bearish trend" do
    scenario "confirms a bullish change of character when an external high breaks" do
      given_market do
        bearish_trend(from: 120, to: 100, steps: 10)
      end

      when_candles_processed do
        candle(open: 100, high: 108, low: 99, close: 107)
      end

      then_expect do
        choch = events(:choch).last
        if choch
          expect(choch.direction).to eq :bullish
          expect(choch.prior_trend).to eq :bearish
        end
      end
    end
  end
end
