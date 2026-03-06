# frozen_string_literal: true

require "simplecov"

SimpleCov.formatter = SimpleCov::Formatter::HTMLFormatter
SimpleCov.start do 
  add_filter /spec/
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
