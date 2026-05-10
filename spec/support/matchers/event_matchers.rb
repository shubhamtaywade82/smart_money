# Domain matchers for SMC events.
# Tests should read like trading playbooks, not implementation checks.

RSpec::Matchers.define :contain_bullish_bos do
  match do |events|
    events.any? { |e| e.is_a?(SmartMoney::Events::BosEvent) && e.bullish? }
  end

  failure_message do |events|
    "expected bullish BOS, got: #{events.map { |e| [e.class, e.respond_to?(:direction) ? e.direction : nil] }.inspect}"
  end
end

RSpec::Matchers.define :contain_bearish_bos do
  match do |events|
    events.any? { |e| e.is_a?(SmartMoney::Events::BosEvent) && e.bearish? }
  end
end

RSpec::Matchers.define :contain_bullish_choch do
  match do |events|
    events.any? { |e| e.is_a?(SmartMoney::Events::ChochEvent) && e.bullish? }
  end
end

RSpec::Matchers.define :contain_bearish_choch do
  match do |events|
    events.any? { |e| e.is_a?(SmartMoney::Events::ChochEvent) && e.bearish? }
  end
end

RSpec::Matchers.define :contain_buy_side_sweep do
  match do |events|
    events.any? { |e| e.is_a?(SmartMoney::Events::SweepEvent) && e.buy_side? }
  end
end

RSpec::Matchers.define :contain_sell_side_sweep do
  match do |events|
    events.any? { |e| e.is_a?(SmartMoney::Events::SweepEvent) && e.sell_side? }
  end
end

RSpec::Matchers.define :contain_aggressive_sweep do
  match do |events|
    events.any? { |e| e.is_a?(SmartMoney::Events::SweepEvent) && e.aggressive? }
  end
end

RSpec::Matchers.define :contain_reclaimed_sweep do
  match do |events|
    events.any? { |e| e.is_a?(SmartMoney::Events::SweepEvent) && e.reclaimed? }
  end
end

RSpec::Matchers.define :contain_buy_side_pool do |near: nil|
  match do |events|
    events.any? do |e|
      next false unless e.is_a?(SmartMoney::Events::LiquidityPoolEvent) && e.buy_side?
      near.nil? || (e.level - near).abs <= 0.5
    end
  end

  failure_message do |events|
    levels = events.select { |e| e.is_a?(SmartMoney::Events::LiquidityPoolEvent) && e.buy_side? }
                   .map(&:level)
    "expected buy-side pool#{" near #{near}" if near}, got levels: #{levels.inspect}"
  end
end

RSpec::Matchers.define :contain_sell_side_pool do |near: nil|
  match do |events|
    events.any? do |e|
      next false unless e.is_a?(SmartMoney::Events::LiquidityPoolEvent) && e.sell_side?
      near.nil? || (e.level - near).abs <= 0.5
    end
  end
end

RSpec::Matchers.define :contain_bullish_displacement do
  match do |events|
    events.any? { |e| e.is_a?(SmartMoney::Events::DisplacementEvent) && e.bullish? }
  end
end

RSpec::Matchers.define :contain_bearish_displacement do
  match do |events|
    events.any? { |e| e.is_a?(SmartMoney::Events::DisplacementEvent) && e.bearish? }
  end
end

RSpec::Matchers.define :contain_bullish_fvg do
  match do |events|
    events.any? { |e| e.is_a?(SmartMoney::Events::FvgEvent) && e.bullish? }
  end
end

RSpec::Matchers.define :contain_bearish_fvg do
  match do |events|
    events.any? { |e| e.is_a?(SmartMoney::Events::FvgEvent) && e.bearish? }
  end
end

RSpec::Matchers.define :contain_mitigated_fvg do
  match do |events|
    events.any? { |e| e.is_a?(SmartMoney::Events::FvgMitigatedEvent) }
  end
end

RSpec::Matchers.define :contain_bullish_order_block do
  match do |events|
    events.any? { |e| e.is_a?(SmartMoney::Events::OrderBlockEvent) && e.bullish? }
  end
end

RSpec::Matchers.define :contain_bearish_order_block do
  match do |events|
    events.any? { |e| e.is_a?(SmartMoney::Events::OrderBlockEvent) && e.bearish? }
  end
end

RSpec::Matchers.define :contain_mitigated_order_block do
  match do |events|
    events.any? { |e| e.is_a?(SmartMoney::Events::OrderBlockMitigatedEvent) }
  end
end

RSpec::Matchers.define :contain_invalidated_order_block do
  match do |events|
    events.any? { |e| e.is_a?(SmartMoney::Events::OrderBlockInvalidatedEvent) }
  end
end
