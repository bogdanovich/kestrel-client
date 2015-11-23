require 'rspec'
require 'pry'
require 'pry-byebug'
require "active_support/core_ext/hash"

spec_dir = File.dirname(__FILE__)

# make sure we load local libs rather than gems first
$: << File.expand_path("#{spec_dir}/../lib")

require 'siberite'

TEST_CONFIG_FILE = File.expand_path("#{spec_dir}/siberite/config/siberite.yml")

RSpec.configure do |config|
  config.mock_with :rr

  config.expect_with :rspec do |c|
    c.syntax = [:should, :expect]
  end

  config.before do
    Siberite::Config.environment = nil
    Siberite::Config.load TEST_CONFIG_FILE
  end

  config.after do
    c = Siberite::Client.new(*Siberite::Config.default)
    c.available_queues.uniq.each do |q|
      c.delete(q) rescue nil
    end
  end
end
