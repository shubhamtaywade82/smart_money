module SmartMoney
  # Top-level orchestrator. Wires together all Phase 1 components.
  # Each instance is fully isolated — no shared state.
  #
  # Usage:
  #   engine = SmartMoney::Engine.new(timeframe: "5m")
  #   engine.subscribe(:bos)   { |e| ... }
  #   engine.subscribe(:choch) { |e| ... }
  #   engine.subscribe(:swing) { |e| ... }
  #   engine.on_candle(candle)
  class Engine
    VALID_EVENTS = %i[swing bos choch].freeze

    attr_reader :timeframe, :trend_state, :swing_engine

    def initialize(timeframe: nil,
                   atr_period: SmartMoney.configuration.default_atr_period,
                   swing_lookback: SmartMoney.configuration.default_swing_lookback,
                   min_displacement_atr: 0.3,
                   require_body_close: true)
      @timeframe   = timeframe
      @candle_count = 0
      @subscribers  = Hash.new { |h, k| h[k] = [] }

      @trend_state  = Structure::TrendState.new

      @swing_engine = Swings::AdaptiveSwingEngine.new(
        atr_period:     atr_period,
        swing_lookback: swing_lookback
      )

      @bos_detector = Structure::BosDetector.new(
        min_displacement_atr: min_displacement_atr,
        require_body_close:   require_body_close
      )

      @choch_detector = Structure::ChochDetector.new(
        min_displacement_atr: min_displacement_atr,
        require_body_close:   require_body_close
      )

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

      @bos_detector.process(candle, @swing_engine, atr, @candle_count, @trend_state)
      @choch_detector.process(candle, @swing_engine, atr, @candle_count, @trend_state)

      self
    end

    def candle_count
      @candle_count
    end

    private

    def wire_internal_subscribers
      @swing_engine.subscribe  { |e| dispatch(:swing, e) }
      @bos_detector.subscribe  { |e| dispatch(:bos,   e) }
      @choch_detector.subscribe { |e| dispatch(:choch, e) }
    end

    def dispatch(event_type, event)
      @subscribers[event_type].each { |sub| sub.call(event) }
    end
  end
end
