# Candle construction helpers for BDD specs.
# Build candles from domain intent, not raw OHLCV math.
module CandleFactory
  BASE_TIMESTAMP = Time.at(1_700_000_000).freeze

  def candle(open:, high:, low:, close:, volume: 1000, timestamp: BASE_TIMESTAMP)
    SmartMoney::Candle.new(
      timestamp: timestamp,
      open:      open.to_f,
      high:      high.to_f,
      low:       low.to_f,
      close:     close.to_f,
      volume:    volume.to_f
    )
  end

  # Strongly bullish candle — small wicks, body-dominant
  def displacement_up(close:, size: 3.0, ts: BASE_TIMESTAMP, volume: 5000)
    open = close - size * 0.85
    candle(open: open, high: close + size * 0.1, low: open - size * 0.05,
           close: close, volume: volume, timestamp: ts)
  end

  # Strongly bearish candle — body-dominant, minimal wicks
  def displacement_down(close:, size: 3.0, ts: BASE_TIMESTAMP, volume: 5000)
    open = close + size * 0.85
    candle(open: open, high: open + size * 0.05, low: close - size * 0.1,
           close: close, volume: volume, timestamp: ts)
  end

  # Candle that sweeps above a level by `wick` then rejects back below (liquidity sweep)
  def sweep_above(level:, wick: 0.5, rejection_close: nil, ts: BASE_TIMESTAMP, volume: 3000)
    rc = rejection_close || (level - wick * 2)
    candle(open: level - 0.1, high: level + wick, low: level - wick * 2,
           close: rc, volume: volume, timestamp: ts)
  end

  # Candle that sweeps below a level then rejects back above
  def sweep_below(level:, wick: 0.5, rejection_close: nil, ts: BASE_TIMESTAMP, volume: 3000)
    rc = rejection_close || (level + wick * 2)
    candle(open: level + 0.1, high: level + wick * 2, low: level - wick,
           close: rc, volume: volume, timestamp: ts)
  end

  # Indecision / doji — equal highs/lows within ATR noise
  def doji(around:, range: 0.2, ts: BASE_TIMESTAMP)
    mid = around.to_f
    candle(open: mid, high: mid + range / 2, low: mid - range / 2, close: mid, timestamp: ts)
  end

  # Trending sequence, oldest-first
  def bull_sequence(from:, step:, count:, range: nil, base_ts: BASE_TIMESTAMP, interval: 300)
    count.times.map do |i|
      close = from + (i + 1) * step
      r = range || step * 0.6
      candle(open: close - step * 0.7, high: close + r * 0.3, low: close - r,
             close: close, timestamp: Time.at(base_ts.to_i + i * interval))
    end
  end

  def bear_sequence(from:, step:, count:, range: nil, base_ts: BASE_TIMESTAMP, interval: 300)
    count.times.map do |i|
      close = from - (i + 1) * step
      r = range || step * 0.6
      candle(open: close + step * 0.7, high: close + r, low: close - r * 0.3,
             close: close, timestamp: Time.at(base_ts.to_i + i * interval))
    end
  end

  # Two candles with the same high — engineered equal-high liquidity
  def equal_high_pair(level:, body_range: 1.5, ts: BASE_TIMESTAMP, interval: 300)
    [
      candle(open: level - body_range, high: level, low: level - body_range * 1.2,
             close: level - 0.3, timestamp: ts),
      candle(open: level - body_range, high: level, low: level - body_range * 1.2,
             close: level - 0.3, timestamp: Time.at(ts.to_i + interval))
    ]
  end

  # Two candles with the same low — engineered equal-low liquidity
  def equal_low_pair(level:, body_range: 1.5, ts: BASE_TIMESTAMP, interval: 300)
    [
      candle(open: level + body_range, high: level + body_range * 1.2, low: level,
             close: level + 0.3, timestamp: ts),
      candle(open: level + body_range, high: level + body_range * 1.2, low: level,
             close: level + 0.3, timestamp: Time.at(ts.to_i + interval))
    ]
  end
end
