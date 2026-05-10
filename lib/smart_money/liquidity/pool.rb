module SmartMoney
  module Liquidity
    # Internal stateful representation of a resting liquidity level.
    # Lives in the engine; never emitted directly — events carry value snapshots.
    class Pool
      attr_reader :side, :first_index, :first_timestamp
      attr_accessor :level, :touch_count, :last_index, :last_timestamp,
                    :swept, :swept_at_index, :sweep_event, :emitted

      def initialize(side:, level:, index:, timestamp:)
        @side            = side
        @level           = level
        @first_index     = index
        @last_index      = index
        @first_timestamp = timestamp
        @last_timestamp  = timestamp
        @touch_count     = 1
        @swept           = false
        @swept_at_index  = nil
        @sweep_event     = nil
        @emitted         = false
      end

      def touch!(level:, index:, timestamp:)
        @level = (@level * @touch_count + level) / (@touch_count + 1.0)
        @touch_count   += 1
        @last_index     = index
        @last_timestamp = timestamp
      end

      def mark_swept!(index, sweep_event)
        @swept          = true
        @swept_at_index = index
        @sweep_event    = sweep_event
      end

      def active?
        !@swept
      end

      def swept?
        @swept
      end

      def buy_side?
        @side == :buy_side
      end

      def sell_side?
        @side == :sell_side
      end
    end
  end
end
