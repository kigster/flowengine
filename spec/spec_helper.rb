# frozen_string_literal: true

require "simplecov"
require "simplecov-lcov"

SimpleCov::Formatter::LcovFormatter.config do |config|
  config.report_with_single_file = true
  config.output_directory = "coverage"
end

SimpleCov.formatters = [
  SimpleCov::Formatter::HTMLFormatter,
  SimpleCov::Formatter::LcovFormatter # Add other formatters here
]

SimpleCov.start do
  add_filter "/spec/"
  enable_coverage :branch
  minimum_coverage 90
end

require "flowengine"
require "rspec/its"

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
  config.order = :random
  Kernel.srand config.seed
end
