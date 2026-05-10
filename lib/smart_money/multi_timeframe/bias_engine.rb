module SmartMoney
  module MultiTimeframe
    # Orchestrates two SMC engines on different timeframes (HTF + LTF) and
    # exposes alignment queries used by strategies.
    #
    # HTF supplies bias; LTF supplies the trigger. Real institutional flow:
    #   HTF: bullish → only longs allowed
    #   LTF: bearish sweep into discount → entry candidate
    class BiasEngine
      attr_reader :htf, :ltf

      def initialize(htf_timeframe:, ltf_timeframe:, **engine_opts)
        @htf = Engine.new(timeframe: htf_timeframe, **engine_opts)
        @ltf = Engine.new(timeframe: ltf_timeframe, **engine_opts)
      end

      def on_htf_candle(candle)
        @htf.on_candle(candle)
        self
      end

      def on_ltf_candle(candle)
        @ltf.on_candle(candle)
        self
      end

      def htf_bias
        @htf.trend_state.state
      end

      def ltf_state
        @ltf.trend_state.state
      end

      def aligned_long?
        htf_bias == :bullish
      end

      def aligned_short?
        htf_bias == :bearish
      end

      def aligned_with?(direction)
        return aligned_long?  if direction == :long || direction == :bullish
        return aligned_short? if direction == :short || direction == :bearish

        false
      end
    end
  end
end
