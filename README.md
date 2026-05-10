# SmartMoney

A production-grade Smart Money Concepts (SMC) engine for Ruby. Streaming-first, event-driven, and stateful — processes one OHLCV candle at a time without ever recomputing history.

Built for: Rails apps, algo-trading systems, WebSocket price feeds, and backtesting pipelines.

## Features

- **Streaming candle processing** — feed candles one at a time, get events back instantly
- **Break of Structure (BOS)** — body-close confirmation with ATR displacement gate; trend-aware (continuation vs reversal)
- **Change of Character (CHOCH)** — detects structural reversals against the prevailing trend
- **Adaptive swing detection** — left/right pivot confirmation with ATR-scaled lookback
- **Liquidity engine** — equal-highs/lows pools (cluster + strict-pivot), wick-pierce/body-rejection sweep detection, post-sweep reclaim tracking
- **Displacement engine** — body-vs-ATR threshold with volume expansion gating; multi-candle streak scoring
- **Fair Value Gap engine** — 3-candle imbalance with detected → partial → mitigated lifecycle events
- **Order Block engine** — validated OBs from displacement origin; tracks mitigation and invalidation
- **Multi-timeframe bias** — `MultiTimeframe::BiasEngine` orchestrates HTF + LTF engines for alignment queries
- **Confluence engine** — combines sweep + opposite-direction displacement (+ optional OB) into scored `SetupEvent`s
- **Pub/sub event system** — subscribe to typed events per engine instance
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

engine.subscribe(:swing)          { |e| puts "#{e.direction} swing at #{e.level}" }
engine.subscribe(:bos)            { |e| puts "BOS #{e.direction}: broke #{e.broken_level}" }
engine.subscribe(:choch)          { |e| puts "CHOCH #{e.direction}: trend shift from #{e.prior_trend}" }
engine.subscribe(:liquidity_pool) { |e| puts "#{e.side} pool at #{e.level} (touches=#{e.touch_count})" }
engine.subscribe(:sweep)          { |e| puts "Sweep #{e.side}: swept #{e.swept_level} reclaimed=#{e.reclaimed?}" }
engine.subscribe(:displacement)   { |e| puts "Displacement #{e.direction} body_atr=#{e.body_atr} streak=#{e.candle_count}" }
engine.subscribe(:fvg)            { |e| puts "FVG #{e.direction} #{e.lower}–#{e.upper} mitigated=#{e.mitigated?}" }
engine.subscribe(:order_block)    { |e| puts "OB #{e.direction} #{e.low}–#{e.high} mitigated=#{e.mitigated?} invalidated=#{e.invalidated?}" }

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

### `LiquidityPoolEvent`

Emitted the first time a level is confirmed as resting liquidity, either by ATR-tolerance cluster (≥2 touches) or strict pivot (right- and left-side strictly inside).

```ruby
e.side         # => :buy_side or :sell_side
e.level        # => Float (running average across touches)
e.touch_count  # => Integer
e.first_index  # => candle index of first touch
```

### `SweepEvent`

Emitted when a candle pierces a known pool's level and rejects with a body close back inside. A reclaim event fires later if price closes back beyond the swept level within `RECLAIM_LOOKAHEAD_CANDLES`.

```ruby
e.side             # => :buy_side or :sell_side
e.swept_level      # => Float
e.wick_extension   # => Float (how far the wick pierced)
e.rejection_close  # => Float
e.displacement_atr # => Float (wick extension / ATR)
e.velocity         # => :normal or :aggressive
e.aggressive?      # => true if rejection >= 1.5 ATR
e.reclaimed?       # => true if a follow-up close invalidated the sweep
```

### `DisplacementEvent`

Emitted when body size relative to ATR clears the threshold. Streak-aware: `candle_count` and `score` accumulate across consecutive same-direction displacements.

```ruby
e.direction      # => :bullish or :bearish
e.body_atr       # => body size / ATR
e.strength       # => :strong (volume expanded) or :weak
e.score          # => sum of body_atr across the streak
e.candle_count   # => streak length
e.origin_candle  # => first candle of the streak
```

### `FvgEvent` lifecycle

`FvgDetectedEvent` → `FvgPartiallyFilledEvent` → `FvgMitigatedEvent`. All share `direction`, `upper`, `lower`, `origin_candle`. The lifecycle subclass conveys state — events remain immutable values.

### `OrderBlockEvent` lifecycle

`OrderBlockDetectedEvent` → `OrderBlockMitigatedEvent` | `OrderBlockInvalidatedEvent`. Origin candle is the last opposite-direction candle preceding a displacement leg.

### `SetupEvent` (Confluence layer)

Emitted by `Strategy::ConfluenceEngine` when a sweep is followed within `SETUP_WINDOW` candles by displacement in the opposite direction.

```ruby
setup.direction    # => :long or :short
setup.sweep        # => the SweepEvent
setup.displacement # => the DisplacementEvent
setup.order_block  # => the OrderBlockDetectedEvent if one was registered in window
setup.score        # => Float (composite of displacement.score, aggressive sweep, OB confluence)
```

## Multi-Timeframe

```ruby
bias = SmartMoney::MultiTimeframe::BiasEngine.new(htf_timeframe: "1h", ltf_timeframe: "5m")

htf_candles.each { |c| bias.on_htf_candle(c) }
ltf_candles.each { |c| bias.on_ltf_candle(c) }

bias.htf_bias        # => :bullish | :bearish | :ranging
bias.aligned_long?   # => true if HTF is bullish
bias.aligned_with?(:short)
```

## Confluence Strategy

```ruby
engine     = SmartMoney::Engine.new
confluence = SmartMoney::Strategy::ConfluenceEngine.new(engine: engine)

confluence.subscribe do |setup|
  next unless setup.score > 2.0
  TradeSignal.create!(direction: setup.direction, score: setup.score, ...)
end

candles.each { |c| engine.on_candle(c) }
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
| `spec/engines/liquidity_engine_spec.rb` | LiquidityEngine: pools, sweeps, reclaims, ATR tolerance |
| `spec/engines/displacement_engine_spec.rb` | DisplacementEngine: body/ATR threshold, volume expansion, multi-candle streaks |
| `spec/engines/fvg_engine_spec.rb` | FVG: detection, partial fill, mitigation |
| `spec/engines/order_block_engine_spec.rb` | OB: validated origin, mitigation, invalidation |
| `spec/multi_timeframe/` | HTF/LTF orchestration and bias alignment |
| `spec/strategy/` | ConfluenceEngine: setup composition + scoring |
| `spec/replay/deterministic_replay_spec.rb` | No future leakage + anti-repainting oracle |
| `spec/acceptance/` | End-to-end scenarios in domain language |

Custom RSpec matchers live in `spec/support/matchers.rb` — `contain_buy_side_sweep`, `contain_bullish_displacement`, `contain_buy_side_pool(near: 100)`, etc.

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
| 2 — Liquidity | ✅ Complete | LiquidityEngine, EQH/EQL pools, sweep + reclaim detection |
| 2 — Displacement | ✅ Complete | DisplacementEngine, volume gating, multi-candle scoring |
| 3 — Institutional | ✅ Complete | OrderBlockEngine + lifecycle, FVG + lifecycle |
| 4 — Multi-timeframe | ✅ Complete | HTF/LTF BiasEngine + alignment queries |
| 5 — Strategy layer | ✅ Complete | ConfluenceEngine + SetupEvent scoring |
| 6 — Streaming/Replay | 🟡 In progress | Snapshot specs, ring buffer optimizations |
| 7 — Sessions / inducement | 🔲 Planned | London/NY/Asia filters, inducement detector |

## License

MIT
