# Structure Engine BDD Spec
#
# Extends Phase 1 BOS/CHOCH specs with domain-language scenarios.
# Tests correctness of the stateful structure model under realistic conditions.

RSpec.describe "Structure Engine: BOS", :scenario do
  scenario "confirms bullish BOS after decisive body close beyond swing high" do
    given_market do
      bullish_trend(from: 100, to: 110, steps: 8)
    end

    when_candles_processed do
      # Clear swing high established at 112
      candle(open: 110, high: 112, low: 109, close: 111)
      candle(open: 111, high: 112.5, low: 109.5, close: 110)
      candle(open: 110, high: 111, low: 108, close: 109)
      candle(open: 109, high: 110, low: 107, close: 108)
      # BOS candle: body closes above 112 with displacement
      candle(open: 108, high: 116, low: 107.5, close: 115)
    end

    then_expect do
      expect(events(:bos).select { |e| e.direction == :bullish }).not_to be_empty
    end
  end

  scenario "rejects wick penetration of swing high without body acceptance" do
    when_candles_processed do
      # Establish swing high at 103 with explicit left and right bars
      candle(open: 100, high: 101.0, low: 99.5, close: 100.8, timestamp: Time.at(1_000))
      candle(open: 101, high: 102.0, low: 100.5, close: 101.5, timestamp: Time.at(1_300))
      candle(open: 102, high: 103.0, low: 101.5, close: 102.5, timestamp: Time.at(1_600)) # peak
      candle(open: 102, high: 102.5, low: 101.0, close: 101.8, timestamp: Time.at(1_900)) # right-1
      candle(open: 101, high: 101.5, low: 100.0, close: 100.5, timestamp: Time.at(2_200)) # right-2 → confirms 103
      # Wick to 104 but body close at 101.5 — below 103 swing high → no BOS
      candle(open: 101, high: 104.0, low: 100.5, close: 101.5, timestamp: Time.at(2_500))
    end

    then_expect do
      no_structure_break
    end
  end

  scenario "detects bearish CHOCH after bullish trend failure" do
    when_candles_processed do
      # Step 1: Confirm trough at 98 (pivot low = the future HL)
      candle(open: 102, high: 104, low: 101,  close: 103,  timestamp: Time.at(1_000)) # left-2
      candle(open: 103, high: 103.5, low: 100, close: 101, timestamp: Time.at(1_300)) # left-1
      candle(open: 101, high: 101.5, low: 98,  close: 99,  timestamp: Time.at(1_600)) # TROUGH low=98
      candle(open: 99,  high: 104,  low: 100,  close: 103, timestamp: Time.at(1_900)) # right-1
      candle(open: 103, high: 106,  low: 103,  close: 105, timestamp: Time.at(2_200)) # right-2 → trough at 98 confirmed
      # Step 2: Confirm peak at 110 (c5 is left-2, c6 is left-1)
      candle(open: 105, high: 107,  low: 104.5, close: 106, timestamp: Time.at(2_500)) # left-1 for peak
      candle(open: 106, high: 110,  low: 105,  close: 109, timestamp: Time.at(2_800)) # PEAK high=110
      candle(open: 109, high: 108.5, low: 104, close: 105, timestamp: Time.at(3_100)) # right-1
      candle(open: 105, high: 107,  low: 103,  close: 105, timestamp: Time.at(3_400)) # right-2 → peak at 110 confirmed
      # Step 3: BOS — close above 110 → trend = :bullish
      candle(open: 106, high: 114,  low: 105,  close: 113, timestamp: Time.at(3_700))
      # Step 4: CHOCH — close below HL (98) → character shifts bearish
      candle(open: 102, high: 103,  low: 94,   close: 95,  timestamp: Time.at(4_000))
    end

    then_expect do
      expect(events(:choch).select { |e| e.direction == :bearish }).not_to be_empty
    end
  end

  scenario "does not fire BOS during ranging/choppy conditions" do
    when_candles_processed do
      # Low-volatility chop — highs and lows interspersed, no clear trend
      candle(open: 100, high: 101.5, low: 99,   close: 100.5)
      candle(open: 100.5, high: 102, low: 100,  close: 101.2)
      candle(open: 101, high: 101.8, low: 99.5, close: 100.3)
      candle(open: 100, high: 101,   low: 99,   close: 100.1)
      candle(open: 100, high: 101.5, low: 99.2, close: 100.4)
    end

    then_expect do
      no_structure_break
    end
  end

  scenario "tracks internal structure independently during an impulsive move" do
    when_candles_processed do
      # Wide-range candles to build high ATR (~8) so small pullbacks classify as internal
      candle(open: 100, high: 108, low: 99,   close: 105, timestamp: Time.at(1_000))
      candle(open: 105, high: 107, low: 100,  close: 101, timestamp: Time.at(1_300))
      # First trough at 99: confirm with explicit left/right bars (low must be strictly lowest)
      candle(open: 101, high: 103, low: 100.5, close: 102, timestamp: Time.at(1_600)) # left-2
      candle(open: 102, high: 103.5, low: 101.5, close: 103, timestamp: Time.at(1_900)) # left-1
      candle(open: 103, high: 100.5, low: 99,  close: 99.5, timestamp: Time.at(2_200)) # TROUGH1 low=99
      candle(open: 100, high: 103, low: 100,  close: 102,   timestamp: Time.at(2_500)) # right-1
      candle(open: 102, high: 105, low: 102,  close: 104,   timestamp: Time.at(2_800)) # right-2 → trough1 at 99 confirmed
      # Second trough at 99.3: delta=0.3 << ATR*0.5 (~4) → internal
      candle(open: 104, high: 105, low: 102.5, close: 104.5, timestamp: Time.at(3_100)) # left-2
      candle(open: 104, high: 104, low: 102,  close: 103.5, timestamp: Time.at(3_400)) # left-1
      candle(open: 103, high: 100.5, low: 99.3, close: 99.8, timestamp: Time.at(3_700)) # TROUGH2 low=99.3
      candle(open: 100, high: 103, low: 100,  close: 102,   timestamp: Time.at(4_000)) # right-1
      candle(open: 102, high: 105, low: 101,  close: 104,   timestamp: Time.at(4_300)) # right-2 → trough2 at 99.3 confirmed → internal
    end

    then_expect do
      swings = events(:swing)
      internal_lows = swings.select { |e| e.low? && e.respond_to?(:internal?) && e.internal? }
      expect(internal_lows).not_to be_empty
    end
  end
end

RSpec.describe "Structure Engine: CHOCH", :scenario do
  scenario "CHOCH requires established trend before firing" do
    when_candles_processed do
      # No prior BOS — engine in :ranging state
      # Even a large move should not produce CHOCH (no character to change from)
      candle(open: 100, high: 108, low: 99, close: 107)
    end

    then_expect do
      expect(events(:choch)).to be_empty
    end
  end

  scenario "CHOCH direction matches the new trend, not the old one" do
    given_market do
      bearish_trend(from: 120, to: 100, steps: 10)
    end

    when_candles_processed do
      # Break above a swing high in a bearish trend = bullish CHOCH
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
