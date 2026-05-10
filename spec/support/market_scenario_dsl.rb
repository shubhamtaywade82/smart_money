# Market Scenario DSL
#
# Provides a readable, domain-language spec interface for SMC scenarios.
# Two setup modes:
#   :streaming (default) — `given_market` builds synthetic candles fed via on_candle
#   :inject              — `given_market` writes state directly into engine internals
#                          (use only for speed-critical specs where setup realism is not the concern)
#
# Usage:
#
#   include MarketScenarioDsl
#
#   scenario "bullish sweep reversal" do
#     given_market do
#       equal_highs at: 19500
#     end
#     when_candles_processed do
#       candle(high: 19510, close: 19480)
#       candle(low: 19400, close: 19550, volume: 8000)
#     end
#     then_expect do
#       liquidity_to_be_swept(:buy_side)
#       displacement_to_be_bullish
#     end
#   end

module MarketScenarioDsl
  include CandleFactory

  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def scenario(description, mode: :streaming, &block)
      it(description) do
        @_scenario_mode   = mode
        @_engine          = SmartMoney::Engine.new
        @_events          = Hash.new { |h, k| h[k] = [] }
        @_setup_candles   = []
        @_scenario_candles = []

        wire_event_collection

        instance_eval(&block)
      end
    end
  end

  # --- Given ---

  def given_market(mode: @_scenario_mode, &block)
    @_setup_context = SetupContext.new(mode: mode)
    @_setup_context.instance_eval(&block) if block
    apply_setup(@_setup_context)
  end

  # --- When ---

  def when_candles_processed(&block)
    collector = CandleCollector.new(self)
    collector.instance_eval(&block) if block
    collector.candles.each { |c| @_engine.on_candle(c) }
  end

  # --- Then ---

  def then_expect(&block)
    assertions = AssertionContext.new(@_events, @_engine, self)
    assertions.instance_eval(&block) if block
  end

  private

  def wire_event_collection
    %i[swing bos choch sweep fvg ob].each do |type|
      @_engine.subscribe(type) { |e| @_events[type] << e } rescue nil
    end
  end

  def apply_setup(ctx)
    if ctx.mode == :inject
      apply_state_injection(ctx)
    else
      apply_streaming_setup(ctx)
    end
  end

  def apply_streaming_setup(ctx)
    ctx.setup_actions.each do |action|
      action.call(@_engine)
    end
  end

  def apply_state_injection(ctx)
    ctx.inject_actions.each do |action|
      action.call(@_engine)
    end
  end

  # --- DSL helper objects ---

  class SetupContext
    include CandleFactory

    attr_reader :mode, :setup_actions, :inject_actions

    def initialize(mode:)
      @mode          = mode
      @setup_actions = []
      @inject_actions = []
    end

    # Stream synthetic candles to establish equal highs at `at` level
    def equal_highs(at:, count: 2, base_ts: CandleFactory::BASE_TIMESTAMP)
      @setup_actions << lambda do |engine|
        # First build a rising sequence to give ATR context
        bull_sequence(from: at - 5, step: 1.0, count: 5, base_ts: base_ts).each { |c| engine.on_candle(c) }
        # Then two candles touching the same high
        equal_high_pair(level: at, ts: Time.at(base_ts.to_i + 5 * 300)).each { |c| engine.on_candle(c) }
        # Slight pullback so the level is left as resting liquidity
        bear_sequence(from: at - 0.5, step: 0.5, count: 3,
                      base_ts: Time.at(base_ts.to_i + 7 * 300)).each { |c| engine.on_candle(c) }
      end

      # Inject mode: directly set state (no candle processing)
      @inject_actions << lambda do |engine|
        # In inject mode we'd set engine internals directly — stubbed until
        # the LiquidityEngine exposes a `seed_equal_highs` method in Phase 2
        engine.instance_variable_get(:@liquidity_engine)
              &.seed_equal_highs(level: at, count: count) rescue nil
      end
    end

    def equal_lows(at:, count: 2, base_ts: CandleFactory::BASE_TIMESTAMP)
      @setup_actions << lambda do |engine|
        bear_sequence(from: at + 5, step: 1.0, count: 5, base_ts: base_ts).each { |c| engine.on_candle(c) }
        equal_low_pair(level: at, ts: Time.at(base_ts.to_i + 5 * 300)).each { |c| engine.on_candle(c) }
        bull_sequence(from: at + 0.5, step: 0.5, count: 3,
                      base_ts: Time.at(base_ts.to_i + 7 * 300)).each { |c| engine.on_candle(c) }
      end

      @inject_actions << lambda do |engine|
        engine.instance_variable_get(:@liquidity_engine)
              &.seed_equal_lows(level: at, count: count) rescue nil
      end
    end

    # Generates a proper oscillating bullish sequence (HH/HL) so the swing engine
    # can confirm pivots and the structure engine can fire BOS events.
    def bullish_trend(from:, to:, steps: 10, base_ts: CandleFactory::BASE_TIMESTAMP)
      @setup_actions << lambda do |engine|
        oscillating_up(from: from, to: to, steps: steps, base_ts: base_ts)
          .each { |c| engine.on_candle(c) }
      end
    end

    def bearish_trend(from:, to:, steps: 10, base_ts: CandleFactory::BASE_TIMESTAMP)
      @setup_actions << lambda do |engine|
        oscillating_down(from: from, to: to, steps: steps, base_ts: base_ts)
          .each { |c| engine.on_candle(c) }
      end
    end

    def htf_bias(direction)
      @inject_actions << lambda do |engine|
        engine.instance_variable_get(:@bias_engine)
              &.force_bias(direction) rescue nil
      end
    end

    private

    # 5-candle wave: 2-rising + 1-PEAK + 2-falling
    # Guarantees pivot detection: PEAK.high is strictly greatest in its 5-bar window.
    # Each wave's trough becomes the HL for the next wave (HH/HL structure).
    def oscillating_up(from:, to:, steps:, base_ts:)
      amp = (to - from).to_f / [steps, 1].max
      current_base = from.to_f  # each wave starts from the prior HL
      candles = []
      i = 0
      steps.times do
        peak_close = current_base + amp * 0.9
        peak_high  = current_base + amp * 1.15  # clearly highest in window
        trough_low = current_base + amp * 0.3   # HL: higher than prior base

        # Rising 1
        mid1 = current_base + amp * 0.4
        candles << candle(open: current_base,    high: mid1 + amp * 0.05,
                          low: current_base - amp * 0.02, close: mid1,
                          timestamp: Time.at(base_ts.to_i + i * 300)); i += 1
        # Rising 2
        mid2 = current_base + amp * 0.75
        candles << candle(open: mid1, high: mid2 + amp * 0.05,
                          low: mid1 - amp * 0.02, close: mid2,
                          timestamp: Time.at(base_ts.to_i + i * 300)); i += 1
        # PEAK
        candles << candle(open: mid2, high: peak_high,
                          low: mid2 - amp * 0.05, close: peak_close,
                          timestamp: Time.at(base_ts.to_i + i * 300)); i += 1
        # Falling 1 — high below peak_high
        fall1_close = current_base + amp * 0.6
        candles << candle(open: peak_close, high: peak_close - amp * 0.05,
                          low: fall1_close - amp * 0.05, close: fall1_close,
                          timestamp: Time.at(base_ts.to_i + i * 300)); i += 1
        # TROUGH — low is clearly lowest, next wave starts here
        candles << candle(open: fall1_close, high: fall1_close + amp * 0.03,
                          low: trough_low - amp * 0.05, close: trough_low + amp * 0.02,
                          timestamp: Time.at(base_ts.to_i + i * 300)); i += 1

        current_base = trough_low  # HL becomes next base
      end
      candles
    end

    def oscillating_down(from:, to:, steps:, base_ts:)
      amp = (from - to).to_f / [steps, 1].max
      current_top = from.to_f
      candles = []
      i = 0
      steps.times do
        trough_close = current_top - amp * 0.9
        trough_low   = current_top - amp * 1.15
        lh_high      = current_top - amp * 0.3   # LH for next wave

        # Falling 1
        mid1 = current_top - amp * 0.4
        candles << candle(open: current_top, high: current_top + amp * 0.02,
                          low: mid1 - amp * 0.05, close: mid1,
                          timestamp: Time.at(base_ts.to_i + i * 300)); i += 1
        # Falling 2
        mid2 = current_top - amp * 0.75
        candles << candle(open: mid1, high: mid1 + amp * 0.02,
                          low: mid2 - amp * 0.05, close: mid2,
                          timestamp: Time.at(base_ts.to_i + i * 300)); i += 1
        # TROUGH (lowest)
        candles << candle(open: mid2, high: mid2 + amp * 0.05,
                          low: trough_low, close: trough_close,
                          timestamp: Time.at(base_ts.to_i + i * 300)); i += 1
        # Rising 1 — low above trough
        rise1 = current_top - amp * 0.6
        candles << candle(open: trough_close, high: rise1 + amp * 0.05,
                          low: trough_close - amp * 0.02, close: rise1,
                          timestamp: Time.at(base_ts.to_i + i * 300)); i += 1
        # LH (highest in recovery, but below prior top)
        candles << candle(open: rise1, high: lh_high + amp * 0.05,
                          low: rise1 - amp * 0.03, close: lh_high - amp * 0.02,
                          timestamp: Time.at(base_ts.to_i + i * 300)); i += 1

        current_top = lh_high
      end
      candles
    end
  end

  class CandleCollector
    include CandleFactory

    attr_reader :candles

    def initialize(ctx)
      @ctx     = ctx
      @candles = []
      @ts_cursor = Time.at(CandleFactory::BASE_TIMESTAMP.to_i + 10_000)
    end

    def candle(**kwargs)
      kwargs[:timestamp] ||= next_ts
      @candles << @ctx.candle(**kwargs)
    end

    def displacement_up(**kwargs)
      kwargs[:ts] ||= next_ts
      @candles << @ctx.displacement_up(**kwargs)
    end

    def displacement_down(**kwargs)
      kwargs[:ts] ||= next_ts
      @candles << @ctx.displacement_down(**kwargs)
    end

    def sweep_above(**kwargs)
      kwargs[:ts] ||= next_ts
      @candles << @ctx.sweep_above(**kwargs)
    end

    def sweep_below(**kwargs)
      kwargs[:ts] ||= next_ts
      @candles << @ctx.sweep_below(**kwargs)
    end

    private

    def next_ts
      t = @ts_cursor
      @ts_cursor = Time.at(@ts_cursor.to_i + 300)
      t
    end
  end

  class AssertionContext
    include RSpec::Matchers

    def initialize(events, engine, example_group)
      @events        = events
      @engine        = engine
      @example_group = example_group
    end

    # Delegate RSpec lifecycle to the enclosing example
    def pending(message = nil)
      @example_group.pending(message)
      # pending continues execution in RSpec; subsequent assertions will raise as expected
    end

    def skip(message = nil)
      @example_group.skip(message)
    end

    def liquidity_to_be_swept(side)
      sweeps = @events[:sweep]
      expect(sweeps).not_to be_empty,
        "Expected a #{side} liquidity sweep event but got none"
      expect(sweeps.last.side).to eq(side)
    end

    def displacement_to_be_bullish
      # Check for bullish BOS or displacement event with bullish direction
      bos = @events[:bos].select { |e| e.respond_to?(:direction) && e.direction == :bullish }
      expect(bos).not_to be_empty,
        "Expected bullish displacement/BOS event but got none"
    end

    def displacement_to_be_bearish
      bos = @events[:bos].select { |e| e.respond_to?(:direction) && e.direction == :bearish }
      expect(bos).not_to be_empty,
        "Expected bearish displacement/BOS event but got none"
    end

    def structure_to_shift(direction)
      choch_events = @events[:choch].select { |e| e.direction == direction }
      bos_events   = @events[:bos].select   { |e| e.direction == direction }
      expect(choch_events + bos_events).not_to be_empty,
        "Expected structure shift to #{direction} but got no BOS or CHOCH events"
    end

    def no_structure_break
      expect(@events[:bos]).to be_empty,
        "Expected no BOS but got: #{@events[:bos].map(&:direction)}"
    end

    def trend_to_be(direction)
      expect(@engine.trend_state.state).to eq(direction)
    end

    def events(type)
      @events[type]
    end
  end
end
