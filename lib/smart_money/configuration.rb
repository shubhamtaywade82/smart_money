module SmartMoney
  class Configuration
    attr_accessor :default_atr_period,
                  :default_swing_lookback,
                  :default_series_capacity,
                  :cache_backend

    def initialize
      @default_atr_period      = 14
      @default_swing_lookback  = :adaptive
      @default_series_capacity = 500
      @cache_backend           = nil
    end
  end
end
