module SmartMoney
  module Liquidity
    # Stateful liquidity engine.
    #
    # Three responsibilities:
    #   1. Detect resting liquidity → emits LiquidityPoolEvent
    #      Two emission triggers:
    #        a) cluster: a level is touched a second time within ATR tolerance
    #        b) pivot:   a strict local max/min is confirmed (right-side lower for max,
    #                    right-side higher for min, left-side likewise)
    #      A pool emits AT MOST ONCE.
    #   2. Detect sweeps of those pools (wick pierces + body rejects) → SweepEvent
    #   3. Track post-sweep reclaim (close back beyond level)         → SweepEvent(reclaimed: true)
    class LiquidityEngine
      EQUAL_TOLERANCE_FACTOR    = 0.20
      MIN_TOLERANCE             = 0.05
      SWEEP_PIERCE_FACTOR       = 0.05
      MIN_PIERCE                = 0.02
      AGGRESSIVE_VELOCITY_ATR   = 1.5
      RECLAIM_LOOKAHEAD_CANDLES = 3

      attr_reader :pools

      def initialize
        @pools         = []
        @subscribers   = []
        @candle_index  = 0
        @recent_sweeps = []
        @recent        = []
      end

      def subscribe(&block)
        @subscribers << block
      end

      def process(candle, atr)
        @candle_index += 1
        @recent << candle
        @recent.shift while @recent.size > 3

        return unless atr&.positive?

        register_high_touch(candle, atr)
        register_low_touch(candle, atr)
        emit_strict_pivot_pools(atr)
        detect_sweeps(candle, atr)
        detect_reclaims(candle)
      end

      def buy_side_pools
        @pools.select(&:buy_side?)
      end

      def sell_side_pools
        @pools.select(&:sell_side?)
      end

      private

      def register_high_touch(candle, atr)
        match = find_matching_pool(:buy_side, candle.high, atr)

        if match
          match.touch!(level: candle.high, index: @candle_index, timestamp: candle.timestamp)
          emit_pool_once(match) if match.touch_count >= 2
        else
          @pools << Pool.new(side: :buy_side, level: candle.high,
                             index: @candle_index, timestamp: candle.timestamp)
        end
      end

      def register_low_touch(candle, atr)
        match = find_matching_pool(:sell_side, candle.low, atr)

        if match
          match.touch!(level: candle.low, index: @candle_index, timestamp: candle.timestamp)
          emit_pool_once(match) if match.touch_count >= 2
        else
          @pools << Pool.new(side: :sell_side, level: candle.low,
                             index: @candle_index, timestamp: candle.timestamp)
        end
      end

      def emit_strict_pivot_pools(atr)
        return unless @recent.size == 3

        previous = @recent[1]
        emit_strict_high_pivot(previous, atr) if strict_high_pivot?
        emit_strict_low_pivot(previous, atr)  if strict_low_pivot?
      end

      def strict_high_pivot?
        left, mid, right = @recent
        left.high < mid.high && right.high < mid.high
      end

      def strict_low_pivot?
        left, mid, right = @recent
        left.low > mid.low && right.low > mid.low
      end

      def emit_strict_high_pivot(candle, atr)
        pool = find_matching_pool(:buy_side, candle.high, atr) ||
               register_pool(:buy_side, candle, candle.high)
        emit_pool_once(pool)
      end

      def emit_strict_low_pivot(candle, atr)
        pool = find_matching_pool(:sell_side, candle.low, atr) ||
               register_pool(:sell_side, candle, candle.low)
        emit_pool_once(pool)
      end

      def register_pool(side, candle, level)
        pool = Pool.new(side: side, level: level,
                        index: @candle_index - 1, timestamp: candle.timestamp)
        @pools << pool
        pool
      end

      def find_matching_pool(side, level, atr)
        tol = tolerance(atr)
        @pools.select { |p| p.side == side && p.active? && (p.level - level).abs <= tol }
              .min_by  { |p| (p.level - level).abs }
      end

      def emit_pool_once(pool)
        return if pool.emitted

        pool.emitted = true
        publish(Events::LiquidityPoolEvent.new(
          timestamp:   pool.last_timestamp,
          side:        pool.side,
          level:       pool.level,
          touch_count: pool.touch_count,
          first_index: pool.first_index,
          last_index:  pool.last_index
        ))
      end

      def detect_sweeps(candle, atr)
        @pools.select(&:active?).each do |pool|
          next unless pool.emitted
          next if pool.last_index == @candle_index

          if pool.buy_side? && pierces_above?(candle, pool, atr) && rejects_below?(candle, pool)
            emit_sweep(candle, pool, atr, :buy_side)
          elsif pool.sell_side? && pierces_below?(candle, pool, atr) && rejects_above?(candle, pool)
            emit_sweep(candle, pool, atr, :sell_side)
          end
        end
      end

      def pierces_above?(candle, pool, atr)
        candle.high > pool.level + pierce_threshold(atr)
      end

      def pierces_below?(candle, pool, atr)
        candle.low < pool.level - pierce_threshold(atr)
      end

      def rejects_below?(candle, pool)
        candle.close < pool.level
      end

      def rejects_above?(candle, pool)
        candle.close > pool.level
      end

      def emit_sweep(candle, pool, atr, side)
        wick_extension = side == :buy_side ? candle.high - pool.level : pool.level - candle.low
        velocity       = aggressive_velocity?(candle, pool, atr) ? :aggressive : :normal

        event = Events::SweepEvent.new(
          timestamp:        candle.timestamp,
          side:             side,
          swept_level:      pool.level,
          wick_extension:   wick_extension.round(4),
          rejection_close:  candle.close,
          displacement_atr: (wick_extension / atr).round(2),
          velocity:         velocity,
          candle_index:     @candle_index
        )

        pool.mark_swept!(@candle_index, event)
        @recent_sweeps << { pool: pool, event: event, expires_at: @candle_index + RECLAIM_LOOKAHEAD_CANDLES }
        publish(event)
      end

      def aggressive_velocity?(candle, pool, atr)
        rejection = pool.buy_side? ? (pool.level - candle.close) : (candle.close - pool.level)
        rejection >= atr * AGGRESSIVE_VELOCITY_ATR
      end

      def detect_reclaims(candle)
        @recent_sweeps.reject! do |entry|
          if entry[:expires_at] < @candle_index
            true
          elsif reclaimed?(candle, entry[:pool])
            publish_reclaim(candle, entry)
            true
          end
        end
      end

      def reclaimed?(candle, pool)
        pool.buy_side? ? candle.close > pool.level : candle.close < pool.level
      end

      def publish_reclaim(candle, entry)
        original = entry[:event]
        publish(Events::SweepEvent.new(
          timestamp:        candle.timestamp,
          side:             original.side,
          swept_level:      original.swept_level,
          wick_extension:   original.wick_extension,
          rejection_close:  candle.close,
          displacement_atr: original.displacement_atr,
          velocity:         original.velocity,
          candle_index:     @candle_index,
          reclaimed:        true
        ))
      end

      def tolerance(atr)
        [atr * EQUAL_TOLERANCE_FACTOR, MIN_TOLERANCE].max
      end

      def pierce_threshold(atr)
        [atr * SWEEP_PIERCE_FACTOR, MIN_PIERCE].max
      end

      def publish(event)
        @subscribers.each { |s| s.call(event) }
      end
    end
  end
end
