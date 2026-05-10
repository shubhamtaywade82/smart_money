# Aliases that read like institutional language.
# `confirm_bullish_bos` reads better in scenarios than `contain_bullish_bos`.

RSpec::Matchers.define :confirm_bullish_bos do
  match { |events| events.any? { |e| e.is_a?(SmartMoney::Events::BosEvent) && e.bullish? } }
  failure_message { |events| "expected bullish BOS in #{events.size} events" }
end

RSpec::Matchers.define :confirm_bearish_bos do
  match { |events| events.any? { |e| e.is_a?(SmartMoney::Events::BosEvent) && e.bearish? } }
end

RSpec::Matchers.define :confirm_bullish_choch do
  match { |events| events.any? { |e| e.is_a?(SmartMoney::Events::ChochEvent) && e.bullish? } }
end

RSpec::Matchers.define :confirm_bearish_choch do
  match { |events| events.any? { |e| e.is_a?(SmartMoney::Events::ChochEvent) && e.bearish? } }
end

# Works on a single event or a collection.
RSpec::Matchers.define :have_displacement do |direction = nil|
  match do |target|
    events = target.is_a?(Array) ? target : [target]
    events.any? do |e|
      next false unless e.respond_to?(:bullish?)
      next false unless e.is_a?(SmartMoney::Events::DisplacementEvent)
      direction.nil? || e.direction == direction
    end
  end
end

RSpec::Matchers.define :be_internal_only_break do
  match do |events|
    events.any? { |e| e.respond_to?(:internal?) && e.internal? } &&
      events.none? { |e| e.is_a?(SmartMoney::Events::BosEvent) }
  end
end
