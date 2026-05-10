require_relative "lib/smart_money/version"

Gem::Specification.new do |spec|
  spec.name    = "smart_money"
  spec.version = SmartMoney::VERSION
  spec.authors = ["Shubham Taywade"]
  spec.email   = ["shubhamtaywade82@gmail.com"]

  spec.summary     = "Production-grade Smart Money Concepts engine for Ruby"
  spec.description = "Event-driven, streaming-first, stateful SMC engine for algo trading, backtesting, and real-time WebSocket feeds"
  spec.homepage    = "https://github.com/shubhamtaywade82/smart_money"
  spec.license     = "MIT"

  spec.required_ruby_version = ">= 3.2.0"

  spec.files = Dir[
    "lib/**/*.rb",
    "sig/**/*.rbs",
    "LICENSE.txt",
    "README.md"
  ]

  spec.require_paths = ["lib"]

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.12"
end
