# Acceptance Spec: Liquidity Sweep Reversal
#
# Top-level behavior spec. Describes a complete institutional trade setup
# from market context through execution signal in readable domain language.
#
# Partially RED (pending Phase 2 engines) — structural BOS/CHOCH assertions
# run against the live Phase 1 engine.

RSpec.describe "Acceptance: Liquidity Sweep Reversal", :scenario do
  scenario "buy-side sweep followed by bearish displacement = bearish reversal setup" do
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

  scenario "sell-side sweep followed by bullish displacement = bullish reversal setup" do
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

  scenario "no trade setup when price breaks equal highs with acceptance (continuation)" do
    given_market do
      equal_highs(at: 100)
    end

    when_candles_processed do
      # Body close above — acceptance, not sweep
      candle(open: 99, high: 102, low: 98.5, close: 101.5)
      candle(open: 101.5, high: 103, low: 101, close: 102.5)
    end

    then_expect do
      sweeps = events(:sweep)
      expect(sweeps.select { |e| e.side == :buy_side }).to be_empty
    end
  end
end

RSpec.describe "Acceptance: Structural BOS Setups", :scenario do
  scenario "bullish BOS after pullback to prior structure = valid long bias" do
    given_market do
      bullish_trend(from: 100, to: 115, steps: 10)
    end

    when_candles_processed do
      # Pullback
      candle(open: 115, high: 116, low: 112, close: 113)
      candle(open: 113, high: 114, low: 111, close: 112)
      # Continuation break
      candle(open: 112, high: 120, low: 111.5, close: 119)
    end

    then_expect do
      structure_to_shift(:bullish)
      trend_to_be(:bullish)
    end
  end

  scenario "bearish CHOCH confirms bias switch from bullish to bearish" do
    when_candles_processed do
      # Step 1: Confirm trough at 98 (the HL that will be broken for CHOCH)
      candle(open: 102, high: 104, low: 101,  close: 103,  timestamp: Time.at(1_000)) # left-2
      candle(open: 103, high: 103.5, low: 100, close: 101, timestamp: Time.at(1_300)) # left-1
      candle(open: 101, high: 101.5, low: 98,  close: 99,  timestamp: Time.at(1_600)) # TROUGH low=98
      candle(open: 99,  high: 104,  low: 100,  close: 103, timestamp: Time.at(1_900)) # right-1
      candle(open: 103, high: 106,  low: 103,  close: 105, timestamp: Time.at(2_200)) # right-2 → trough at 98 confirmed
      # Step 2: Confirm peak at 110
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
end

RSpec.describe "Acceptance: Performance", :scenario do
  it "processes 500 candles in under 50ms" do
    engine = SmartMoney::Engine.new

    ts = Time.at(1_700_000_000)
    candles = 500.times.map do |i|
      c = candle(open: 100 + Math.sin(i * 0.05) * 10,
                 high: 100 + Math.sin(i * 0.05) * 10 + 1.5,
                 low:  100 + Math.sin(i * 0.05) * 10 - 1.5,
                 close: 100 + Math.sin(i * 0.05) * 10 + 0.5,
                 timestamp: Time.at(ts.to_i + i * 300))
      c
    end

    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    candles.each { |c| engine.on_candle(c) }
    elapsed_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000

    expect(elapsed_ms).to be < 50,
      "Engine processed 500 candles in #{elapsed_ms.round(1)}ms — exceeds 50ms budget"
  end
end
