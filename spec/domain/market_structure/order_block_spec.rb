RSpec.describe "order block lifecycle", :order_block do
  let(:engine) { SmartMoney::Engine.new }
  let(:obs)    { [] }

  before { engine.subscribe(:order_block) { |e| obs << e } }

  context "during a bullish displacement leg" do
    context "when the leg is preceded by a bearish candle" do
      before do
        engine.on_candle(candle(open: 103, high: 104, low: 100, close: 101))
        engine.on_candle(candle(open: 101, high: 102, low: 99,  close: 100))
        engine.on_candle(candle(open: 100, high: 101, low: 97,  close: 97.5,
                                timestamp: Time.at(3_000)))
        engine.on_candle(displacement_up(close: 107, size: 9.5, volume: 8000,
                                         ts: Time.at(3_300)))
      end

      it "registers a bullish order block" do
        expect(obs).to contain_bullish_order_block
      end

      it "anchors the order block to the last opposite-direction candle" do
        bullish = obs.select(&:bullish?)
        expect(bullish.last.origin_candle.timestamp).to eq Time.at(3_000)
      end
    end
  end

  context "during a bearish displacement leg" do
    context "when the leg is preceded by a bullish candle" do
      before do
        engine.on_candle(candle(open: 97,  high: 100, low: 96, close: 99))
        engine.on_candle(candle(open: 99,  high: 101, low: 98, close: 100))
        engine.on_candle(candle(open: 100, high: 103, low: 99, close: 102.5,
                                timestamp: Time.at(3_000)))
        engine.on_candle(displacement_down(close: 92, size: 10.0, volume: 9000,
                                           ts: Time.at(3_300)))
      end

      it "registers a bearish order block" do
        expect(obs).to contain_bearish_order_block
      end
    end
  end

  context "after a bullish order block has been registered" do
    let(:engine) { SmartMoney::Engine.new }
    let(:obs)    { [] }

    before do
      engine.subscribe(:order_block) { |e| obs << e }
      # Two bearish context candles, then the OB origin (bearish), then displacement_up
      engine.on_candle(candle(open: 103, high: 104, low: 100, close: 101))
      engine.on_candle(candle(open: 101, high: 102, low: 99,  close: 100))
      engine.on_candle(candle(open: 100, high: 101, low: 97,  close: 97.5,
                              timestamp: Time.at(3_000)))
      engine.on_candle(displacement_up(close: 107, size: 9.5, volume: 8000,
                                       ts: Time.at(3_300)))
    end

    context "when price retraces back into the order block zone" do
      before do
        # OB zone is [97, 101]; pull a candle whose range overlaps it.
        engine.on_candle(candle(open: 106, high: 106.5, low: 100, close: 101,
                                volume: 4000, timestamp: Time.at(3_600)))
      end

      it "emits an order-block mitigation event" do
        expect(obs).to contain_mitigated_order_block
      end
    end

    context "when price closes decisively below the order block low" do
      before do
        # Strong close below 97 — invalidates the bullish OB
        engine.on_candle(candle(open: 105, high: 106, low: 92, close: 93,
                                volume: 9000, timestamp: Time.at(3_600)))
      end

      it "emits an order-block invalidation event" do
        expect(obs).to contain_invalidated_order_block
      end
    end
  end

  context "during ranging price action without displacement" do
    before do
      engine.on_candle(candle(open: 102, high: 103, low: 99, close: 100))
      engine.on_candle(candle(open: 100, high: 101, low: 98, close: 99))
      engine.on_candle(candle(open: 99,  high: 100, low: 97, close: 98))
    end

    it "does not register any order block from individual bearish candles" do
      expect(obs).to be_empty
    end
  end
end
