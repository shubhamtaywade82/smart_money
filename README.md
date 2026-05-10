# SmartMoney

A production-grade Smart Money Concepts (SMC) engine for Ruby. Streaming-first, event-driven, and stateful — processes one OHLCV candle at a time without ever recomputing history.

Built for: Rails apps, algo-trading systems, WebSocket price feeds, and backtesting pipelines.

## Features

- **Streaming candle processing** — feed candles one at a time, get events back instantly
- **Break of Structure (BOS)** — body-close confirmation with ATR displacement gate; trend-aware (continuation vs reversal)
- **Change of Character (CHOCH)** — detects structural reversals against the prevailing trend
- **Adaptive swing detection** — left/right pivot confirmation with ATR-scaled lookback
- **Equal-high/low clustering** — identifies engineered liquidity levels
- **Pub/sub event system** — subscribe to `:swing`, `:bos`, `:choch` events per engine instance
- **Zero future leakage** — events are never emitted using data from future candles
- **No repainting** — confirmed events are never retracted
- **Rails-compatible** — no ActiveSupport dependency; optional `SmartMoney.configure` block

## Installation

```ruby
# Gemfile
gem "smart_money"
```

```bash
bundle install
```

Requires Ruby >= 3.2.

## Quick Start

```ruby
require "smart_money"

engine = SmartMoney::Engine.new

engine.subscribe(:swing) { |e| puts "#{e.direction} swing at #{e.level}" }
engine.subscribe(:bos)   { |e| puts "BOS #{e.direction}: broke #{e.broken_level}" }
engine.subscribe(:choch) { |e| puts "CHOCH #{e.direction}: trend shift from #{e.prior_trend}" }

# Feed candles one at a time (from a WebSocket, CSV, database, etc.)
candle = SmartMoney::Candle.new(
  timestamp: Time.now,
  open:  100.0,
  high:  102.5,
  low:   99.0,
  close: 101.8,
  volume: 4200
)

engine.on_candle(candle)
```

## Event Types

### `SwingEvent`

Emitted when a pivot high or low is confirmed after sufficient right-side bars.

```ruby
engine.subscribe(:swing) do |e|
  e.direction   # => :high or :low
  e.level       # => Float (the high or low price)
  e.timestamp   # => Time (of the pivot candle, not the confirmation candle)
  e.swing_type  # => :external or :internal
  e.equal_cluster # => true if within ATR tolerance of the prior swing (EQH/EQL)
  e.high?       # => true if pivot high
  e.low?        # => true if pivot low
  e.external?   # => true if major structural swing
  e.internal?   # => true if minor internal swing
end
```

### `BosEvent`

Emitted when price breaks and closes beyond a confirmed structural swing.

```ruby
engine.subscribe(:bos) do |e|
  e.direction        # => :bullish or :bearish
  e.broken_level     # => Float (the swing level that was broken)
  e.close_price      # => Float
  e.displacement_atr # => Float (displacement expressed as multiples of ATR)
  e.timestamp        # => Time
  e.bullish?         # => true if bullish BOS
  e.bearish?         # => true if bearish BOS
end
```

### `ChochEvent`

Emitted when price breaks against the prevailing trend direction.

```ruby
engine.subscribe(:choch) do |e|
  e.direction        # => :bullish or :bearish (the NEW direction)
  e.prior_trend      # => :bullish or :bearish (the trend being reversed)
  e.broken_level     # => Float
  e.close_price      # => Float
  e.displacement_atr # => Float
  e.timestamp        # => Time
end
```

## Configuration

```ruby
SmartMoney.configure do |c|
  c.default_atr_period       = 14    # Wilder's ATR smoothing period
  c.default_swing_lookback   = :adaptive  # or an Integer (e.g. 3)
  c.default_series_capacity  = 500   # ring buffer size
end
```

### Per-engine options

```ruby
engine = SmartMoney::Engine.new(
  timeframe:            "5m",
  atr_period:           14,
  swing_lookback:       :adaptive,  # widens automatically in high-volatility conditions
  min_displacement_atr: 0.3,        # BOS/CHOCH displacement gate (fraction of ATR)
  require_body_close:   true        # body-close confirmation required (rejects wick-only breaks)
)
```

## Design Principles

**Streaming-first** — `on_candle` is O(1). No batch recomputation. No dataframe-style APIs.

**Event-driven** — engines emit typed events; consumers subscribe. No polling, no return values to check.

**No repainting** — the anti-repainting guarantee is enforced by the architecture: pivot confirmation requires right-side bars, BOS requires a body close, and no event is ever retracted after emission.

**Deterministic** — given the same candle sequence, two engine instances always produce identical events. No internal randomness, no `Time.now` inside the hot path.

**Trend-aware BOS/CHOCH** — in a bullish trend, a break below a swing low is routed to CHOCH (not BOS) and vice versa, matching institutional SMC semantics.

## BDD Spec Suite

The spec suite is the architecture. Run it with:

```bash
bundle exec rspec
```

Spec categories:

| File | Purpose |
|------|---------|
| `spec/smart_money/` | Unit tests for all core data structures and engines |
| `spec/engines/swing_engine_spec.rb` | Swing pivot detection contract |
| `spec/engines/structure_engine_spec.rb` | BOS/CHOCH correctness |
| `spec/engines/liquidity_engine_spec.rb` | Phase 2 — LiquidityEngine contract (pending) |
| `spec/engines/displacement_engine_spec.rb` | Phase 2 — DisplacementEngine contract (pending) |
| `spec/engines/fvg_engine_spec.rb` | Phase 3 — Fair Value Gap contract (pending) |
| `spec/engines/order_block_engine_spec.rb` | Phase 3 — Order Block contract (pending) |
| `spec/replay/deterministic_replay_spec.rb` | No future leakage + anti-repainting oracle |
| `spec/acceptance/` | Full scenario tests in domain language |

Phase 2/3 specs are marked `pending` — they serve as the executable design contract for upcoming engines.

## Rails Integration

```ruby
# config/initializers/smart_money.rb
SmartMoney.configure do |c|
  c.default_atr_period     = 14
  c.default_swing_lookback = :adaptive
end

# In a Rails service / background job:
class MarketAnalysisJob < ApplicationJob
  def perform(candles)
    engine = SmartMoney::Engine.new(timeframe: "15m")

    engine.subscribe(:bos) do |event|
      TradeSignal.create!(
        direction:   event.direction,
        level:       event.broken_level,
        fired_at:    event.timestamp
      )
    end

    candles.each { |c| engine.on_candle(c) }
  end
end
```

## Roadmap

| Phase | Status | Features |
|-------|--------|---------|
| 1 — Foundation | ✅ Complete | CandleSeries, SwingEngine, BOS/CHOCH, TrendState, Engine |
| 2 — Liquidity | 🔲 Planned | LiquidityEngine, EQH/EQL detection, sweep detection |
| 2 — Displacement | 🔲 Planned | DisplacementEngine, volume confirmation, FVG creation |
| 3 — Institutional | 🔲 Planned | OrderBlockEngine, FVG mitigation tracking |
| 4 — Multi-timeframe | 🔲 Planned | HTF bias engine, MTF confluence |
| 5 — Strategy layer | 🔲 Planned | Entry/exit policy, risk/reward evaluation |

## License

MIT
