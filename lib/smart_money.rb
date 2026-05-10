require_relative "smart_money/version"
require_relative "smart_money/configuration"
require_relative "smart_money/errors/invalid_series_error"
require_relative "smart_money/utils/math_utils"
require_relative "smart_money/candle"
require_relative "smart_money/candle_series"

require_relative "smart_money/events/base_event"
require_relative "smart_money/events/swing_event"
require_relative "smart_money/events/bos_event"
require_relative "smart_money/events/choch_event"
require_relative "smart_money/events/liquidity_pool_event"
require_relative "smart_money/events/sweep_event"
require_relative "smart_money/events/displacement_event"
require_relative "smart_money/events/fvg_event"
require_relative "smart_money/events/order_block_event"

require_relative "smart_money/swings/pivot_detector"
require_relative "smart_money/swings/adaptive_swing_engine"
require_relative "smart_money/structure/trend_state"
require_relative "smart_money/structure/bos_detector"
require_relative "smart_money/structure/choch_detector"

require_relative "smart_money/liquidity/pool"
require_relative "smart_money/liquidity/liquidity_engine"
require_relative "smart_money/imbalance/displacement_engine"
require_relative "smart_money/imbalance/fvg"
require_relative "smart_money/imbalance/fvg_engine"
require_relative "smart_money/order_blocks/order_block"
require_relative "smart_money/order_blocks/order_block_engine"

require_relative "smart_money/engine"

module SmartMoney
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield configuration
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end
