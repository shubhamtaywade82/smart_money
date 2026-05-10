module SmartMoney
  module Structure
    # Tracks market structure state machine.
    # State transitions are driven by confirmed BOS events.
    # Holds references to the last HH, HL, LH, LL swing points.
    class TrendState
      STATES = %i[ranging bullish bearish].freeze

      attr_reader :state, :last_hh, :last_hl, :last_lh, :last_ll,
                  :bullish_bos_count, :bearish_bos_count

      def initialize
        @state             = :ranging
        @last_hh           = nil
        @last_hl           = nil
        @last_lh           = nil
        @last_ll           = nil
        @bullish_bos_count = 0
        @bearish_bos_count = 0
      end

      def established?
        @state != :ranging
      end

      def bullish?
        @state == :bullish
      end

      def bearish?
        @state == :bearish
      end

      # Called by BosDetector when a bullish BOS fires.
      # Returns the new state.
      def on_bullish_bos(swing_high_pivot)
        @last_hh           = swing_high_pivot
        @bearish_bos_count = 0
        @bullish_bos_count += 1
        @state = :bullish if @bullish_bos_count >= 1
        @state
      end

      # Called by BosDetector when a bearish BOS fires.
      def on_bearish_bos(swing_low_pivot)
        @last_ll           = swing_low_pivot
        @bullish_bos_count = 0
        @bearish_bos_count += 1
        @state = :bearish if @bearish_bos_count >= 1
        @state
      end

      # Update HL reference after a pullback low is confirmed
      def update_hl(pivot)
        @last_hl = pivot
      end

      # Update LH reference after a rally high is confirmed in bearish structure
      def update_lh(pivot)
        @last_lh = pivot
      end

      def to_s
        "#<TrendState state=#{@state} HH=#{@last_hh&.level} HL=#{@last_hl&.level} LH=#{@last_lh&.level} LL=#{@last_ll&.level}>"
      end
    end
  end
end
