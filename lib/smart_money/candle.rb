module SmartMoney
  Candle = Data.define(:timestamp, :open, :high, :low, :close, :volume) do
    def bullish?
      close > open
    end

    def bearish?
      close < open
    end

    def body_high
      [open, close].max
    end

    def body_low
      [open, close].min
    end

    def body_size
      (close - open).abs
    end

    def range
      high - low
    end

    def upper_wick
      high - body_high
    end

    def lower_wick
      body_low - low
    end

    def to_s
      "#<Candle #{timestamp} O=#{open} H=#{high} L=#{low} C=#{close} V=#{volume}>"
    end
  end
end
