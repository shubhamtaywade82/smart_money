module SmartMoney
  # Top-level orchestrator. Wires together all SMC engines.
  # Each instance is fully isolated — no shared state.
  #
  # Usage:
  #   engine = SmartMoney::Engine.new(timeframe: "5m")
  #   engine.subscribe(:bos)            { |e| ... }
  #   engine.subscribe(:liquidity_pool) { |e| ... }
  #   engine.subscribe(:sweep)          { |e| ... }
  #   engine.on_candle(candle)
  class Engine
    VALID_EVENTS = %i[
      swing
      bos
      choch
      liquidity_pool
      sweep
      displacement
      fvg
      order_block
    ].freeze

    attr_reader :timeframe, :trend_state, :swing_engine, :liquidity_engine,
                :displacement_engine, :fvg_engine, :order_block_engine

    def initialize(timeframe: nil,
                   atr_period: SmartMoney.configuration.default_atr_period,
                   swing_lookback: SmartMoney.configuration.default_swing_lookback,
                   min_displacement_atr: 0.3,
                   require_body_close: true)
      @timeframe    = timeframe
      @candle_count = 0
      @subscribers  = Hash.new { |h, k| h[k] = [] }

      build_engines(atr_period: atr_period,
                    swing_lookback: swing_lookback,
                    min_displacement_atr: min_displacement_atr,
                    require_body_close: require_body_close)
      wire_internal_subscribers
    end

    def subscribe(event_type, &block)
      raise ArgumentError, "Unknown event type: #{event_type}. Valid: #{VALID_EVENTS}" unless VALID_EVENTS.include?(event_type)

      @subscribers[event_type] << block
      self
    end

    def on_candle(candle)
      @candle_count += 1

      @swing_engine.process(candle)
      atr = @swing_engine.atr

      @liquidity_engine.process(candle, atr)
      @displacement_engine.process(candle, atr)
      @fvg_engine.process(candle)
      @order_block_engine.process(candle, atr)

      @bos_detector.process(candle,   @swing_engine, atr, @candle_count, @trend_state)
      @choch_detector.process(candle, @swing_engine, atr, @candle_count, @trend_state)

      self
    end

    def candle_count
      @candle_count
    end

    private

    def build_engines(atr_period:, swing_lookback:, min_displacement_atr:, require_body_close:)
      @trend_state         = Structure::TrendState.new
      @swing_engine        = Swings::AdaptiveSwingEngine.new(
        atr_period: atr_period, swing_lookback: swing_lookback
      )
      @liquidity_engine    = Liquidity::LiquidityEngine.new
      @displacement_engine = Imbalance::DisplacementEngine.new
      @fvg_engine          = Imbalance::FvgEngine.new
      @order_block_engine  = OrderBlocks::OrderBlockEngine.new
      @bos_detector        = Structure::BosDetector.new(
        min_displacement_atr: min_displacement_atr,
        require_body_close:   require_body_close
      )
      @choch_detector      = Structure::ChochDetector.new(
        min_displacement_atr: min_displacement_atr,
        require_body_close:   require_body_close
      )
    end

    def wire_internal_subscribers
      @swing_engine.subscribe        { |e| dispatch(:swing, e) }
      @bos_detector.subscribe        { |e| dispatch(:bos, e) }
      @choch_detector.subscribe      { |e| dispatch(:choch, e) }
      @liquidity_engine.subscribe    { |e| dispatch_liquidity(e) }
      @displacement_engine.subscribe { |e| dispatch(:displacement, e) }
      @fvg_engine.subscribe          { |e| dispatch(:fvg, e) }
      @order_block_engine.subscribe  { |e| dispatch(:order_block, e) }
    end

    def dispatch_liquidity(event)
      key = event.is_a?(Events::SweepEvent) ? :sweep : :liquidity_pool
      dispatch(key, event)
    end

    def dispatch(event_type, event)
      @subscribers[event_type].each { |sub| sub.call(event) }
    end
  end
end
