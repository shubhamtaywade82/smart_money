module SmartMoney
  module OrderBlocks
    # Detects validated Order Blocks: the last opposite-direction candle
    # before a displacement leg, registered with structure interaction in mind.
    #
    # Lifecycle events:
    #   - OrderBlockDetectedEvent     when a new OB is registered
    #   - OrderBlockMitigatedEvent    when price retests into the OB zone
    #   - OrderBlockInvalidatedEvent  when price closes decisively beyond the OB
    #
    # NOT every opposite candle is an OB. Required:
    #   1. Following candle (or current) is a displacement candle (body >= MIN_DISPLACEMENT_ATR * ATR)
    #   2. Origin is the most recent opposite-direction candle within LOOKBACK
    class OrderBlockEngine
      MIN_DISPLACEMENT_ATR  = 1.5
      LOOKBACK              = 8
      INVALIDATION_MARGIN   = 0.1   # atr multiples of close beyond the wrong side
      RECENT_BUFFER         = 12

      def initialize
        @subscribers       = []
        @recent            = []
        @active_blocks     = []
        @registered_origins = {}
        @candle_index      = 0
      end

      def subscribe(&block)
        @subscribers << block
      end

      def process(candle, atr)
        @candle_index += 1
        update_active_blocks(candle, atr)
        @recent << { candle: candle, index: @candle_index }
        @recent.shift while @recent.size > RECENT_BUFFER
        detect_new_ob(candle, atr) if atr&.positive?
      end

      private

      def detect_new_ob(displacement_candle, atr)
        return unless displacement?(displacement_candle, atr)

        direction = displacement_candle.bullish? ? :bullish : :bearish
        origin    = find_origin_for(direction)
        return unless origin
        return if @registered_origins[origin[:index]]

        register(direction, origin, displacement_candle, atr)
      end

      def displacement?(candle, atr)
        candle.body_size >= atr * MIN_DISPLACEMENT_ATR
      end

      def find_origin_for(direction)
        @recent.last(LOOKBACK + 1)[0..-2].reverse.find do |entry|
          opposite_to?(direction, entry[:candle])
        end
      end

      def opposite_to?(direction, candle)
        direction == :bullish ? candle.bearish? : candle.bullish?
      end

      def register(direction, origin, displacement_candle, atr)
        ob = OrderBlock.new(
          direction:          direction,
          origin_candle:      origin[:candle],
          origin_index:       origin[:index],
          displacement_score: (displacement_candle.body_size / atr).round(2)
        )
        @registered_origins[origin[:index]] = true
        @active_blocks << ob
        publish(detected_event(ob))
      end

      def update_active_blocks(candle, atr)
        @active_blocks.each do |ob|
          next unless ob.fresh?

          if invalidated_by?(ob, candle, atr)
            ob.state = :invalidated
            publish(invalidated_event(ob, candle))
          elsif retests?(ob, candle)
            ob.state = :mitigated
            publish(mitigated_event(ob, candle))
          end
        end
      end

      def invalidated_by?(ob, candle, atr)
        return false unless atr&.positive?

        margin = atr * INVALIDATION_MARGIN
        ob.bullish? ? candle.close < ob.low - margin : candle.close > ob.high + margin
      end

      def retests?(ob, candle)
        candle.low <= ob.high && candle.high >= ob.low
      end

      def detected_event(ob)
        Events::OrderBlockDetectedEvent.new(
          timestamp:          ob.timestamp,
          direction:          ob.direction,
          high:               ob.high,
          low:                ob.low,
          origin_candle:      ob.origin_candle,
          origin_index:       ob.origin_index,
          displacement_score: ob.displacement_score
        )
      end

      def mitigated_event(ob, candle)
        Events::OrderBlockMitigatedEvent.new(
          timestamp:          candle.timestamp,
          direction:          ob.direction,
          high:               ob.high,
          low:                ob.low,
          origin_candle:      ob.origin_candle,
          origin_index:       ob.origin_index,
          displacement_score: ob.displacement_score
        )
      end

      def invalidated_event(ob, candle)
        Events::OrderBlockInvalidatedEvent.new(
          timestamp:          candle.timestamp,
          direction:          ob.direction,
          high:               ob.high,
          low:                ob.low,
          origin_candle:      ob.origin_candle,
          origin_index:       ob.origin_index,
          displacement_score: ob.displacement_score
        )
      end

      def publish(event)
        @subscribers.each { |s| s.call(event) }
      end
    end
  end
end
