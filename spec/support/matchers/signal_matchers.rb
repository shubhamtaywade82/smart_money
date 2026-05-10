# Signal-level matchers — read like trading playbooks.

RSpec::Matchers.define :be_valid_long_signal do
  match do |setup|
    setup.is_a?(SmartMoney::Events::SetupEvent) &&
      setup.long? &&
      setup.sweep&.sell_side? &&
      setup.displacement&.bullish?
  end

  failure_message do |setup|
    "expected a valid long setup with sell-side sweep + bullish displacement, got #{setup.inspect}"
  end
end

RSpec::Matchers.define :be_valid_short_signal do
  match do |setup|
    setup.is_a?(SmartMoney::Events::SetupEvent) &&
      setup.short? &&
      setup.sweep&.buy_side? &&
      setup.displacement&.bearish?
  end
end

RSpec::Matchers.define :have_score_above do |threshold|
  match { |setup| setup.respond_to?(:score) && setup.score > threshold }
  failure_message { |setup| "expected score > #{threshold}, got #{setup&.score}" }
end

RSpec::Matchers.define :include_order_block_confluence do
  match { |setup| !setup.order_block.nil? }
end
