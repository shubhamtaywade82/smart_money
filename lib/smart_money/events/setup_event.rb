module SmartMoney
  module Events
    # Emitted by the ConfluenceEngine when independent SMC signals align
    # within a bounded window into a tradable setup.
    #
    # Composition: a sweep against the prior trend + displacement in the
    # opposite direction. Optional confluence: a fresh order block in the
    # entry direction.
    class SetupEvent < BaseEvent
      attr_reader :direction, :sweep, :displacement, :order_block, :score, :candle_index

      def initialize(timestamp:, direction:, sweep:, displacement:,
                     order_block: nil, score:, candle_index:, timeframe: nil)
        @direction    = direction
        @sweep        = sweep
        @displacement = displacement
        @order_block  = order_block
        @score        = score
        @candle_index = candle_index
        super(timestamp: timestamp, timeframe: timeframe)
      end

      def long?
        @direction == :long
      end

      def short?
        @direction == :short
      end
    end
  end
end
