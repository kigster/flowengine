# frozen_string_literal: true

require "simplecov"
require "coverage/badge"

CoverageStats = Data.define(:percent) do
  def self.from(percent)
    new(percent:)
  end
end

SimpleCov.start do
  SimpleCov.add_filter(/spec/)
  SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new(
    [
      SimpleCov::Formatter::HTMLFormatter,
      Coverage::Badge::Formatter
    ]
  )
end

require "flowengine"
require "rspec/its"
require "stringio"

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
  config.order = :random
  Kernel.srand config.seed

  config.around do |example|
    original_stdout = $stdout
    original_stderr = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new
    example.run
  ensure
    $stdout = original_stdout
    $stderr = original_stderr
  end
end

SimpleCov.at_exit do
  SimpleCov.result.format!
  puts "Coverage: #{SimpleCov.result.covered_percent.round(2)}%"

  FileUtils.mv("coverage/badge.svg", "docs/badges/coverage_badge.svg")
end
