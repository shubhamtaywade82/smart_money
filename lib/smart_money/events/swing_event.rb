module SmartMoney
  module Events
    class SwingEvent < BaseEvent
      attr_reader :direction, :level, :candle_index, :swing_type, :equal_cluster

      # direction: :high or :low
      # swing_type: :internal or :external
      # equal_cluster: true when merged as EQH/EQL
      def initialize(timestamp:, direction:, level:, candle_index:, swing_type: :external, equal_cluster: false, timeframe: nil)
        @direction     = direction
        @level         = level
        @candle_index  = candle_index
        @swing_type    = swing_type
        @equal_cluster = equal_cluster
        super(timestamp: timestamp, timeframe: timeframe)
      end

      def high?
        @direction == :high
      end

      def low?
        @direction == :low
      end

      def external?
        @swing_type == :external
      end

      def internal?
        @swing_type == :internal
      end
    end
  end
end
