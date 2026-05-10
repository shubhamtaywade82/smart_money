module SmartMoney
  module Events
    class BaseEvent
      attr_reader :timestamp, :timeframe

      def initialize(timestamp:, timeframe: nil)
        @timestamp = timestamp
        @timeframe = timeframe
        freeze
      end

      def type
        self.class.name.split("::").last.sub("Event", "").downcase.to_sym
      end

      def to_h
        instance_variables.each_with_object({}) do |var, hash|
          hash[var.to_s.delete("@").to_sym] = instance_variable_get(var)
        end
      end

      def to_s
        "#<#{self.class.name} #{to_h.map { |k, v| "#{k}=#{v}" }.join(" ")}>"
      end
    end
  end
end
