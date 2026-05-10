module SmartMoney
  module Strategy
    # Confluence engine.
    #
    # Listens to an Engine's events and combines them into a SetupEvent when
    # independent signals align within SETUP_WINDOW candles:
    #
    #   buy-side sweep   + bearish displacement → short setup
    #   sell-side sweep  + bullish displacement → long  setup
    #
    # The engine does NOT execute trades. It emits a tradable signal
    # carrying the supporting evidence (sweep + displacement, optional OB).
    class ConfluenceEngine
      SETUP_WINDOW = 5

      def initialize(engine:)
        @engine      = engine
        @subscribers = []
        @pending     = []
        wire(engine)
      end

      def subscribe(&block)
        @subscribers << block
      end

      private

      def wire(engine)
        engine.subscribe(:sweep)        { |e| record_sweep(e) }
        engine.subscribe(:displacement) { |e| try_match_displacement(e) }
        engine.subscribe(:order_block)  { |e| record_order_block(e) }
      end

      def record_sweep(event)
        return if event.reclaimed?

        @pending << {
          sweep:        event,
          expected_dir: event.buy_side? ? :bearish : :bullish,
          target_side:  event.buy_side? ? :short  : :long,
          born_at:      event.candle_index,
          order_block:  nil
        }
      end

      def record_order_block(event)
        return unless event.is_a?(Events::OrderBlockDetectedEvent)

        @pending.each do |entry|
          aligned = entry[:target_side] == :long ? event.bullish? : event.bearish?
          entry[:order_block] ||= event if aligned
        end
      end

      def try_match_displacement(event)
        prune_expired_against(event.candle_index)

        match = @pending.find { |entry| entry[:expected_dir] == event.direction }
        return unless match

        @pending.delete(match)
        publish(build_setup(match, event))
      end

      def build_setup(entry, displacement)
        sweep = entry[:sweep]
        Events::SetupEvent.new(
          timestamp:    displacement.timestamp,
          direction:    entry[:target_side],
          sweep:        sweep,
          displacement: displacement,
          order_block:  entry[:order_block],
          score:        compute_score(sweep, displacement, entry[:order_block]),
          candle_index: displacement.candle_index
        )
      end

      def compute_score(sweep, displacement, order_block)
        base = displacement.score
        base += 1.0 if sweep.aggressive?
        base += 1.0 if order_block
        base.round(2)
      end

      def prune_expired_against(current_index)
        @pending.reject! { |entry| current_index - entry[:born_at] > SETUP_WINDOW }
      end

      def publish(event)
        @subscribers.each { |s| s.call(event) }
      end
    end
  end
end
