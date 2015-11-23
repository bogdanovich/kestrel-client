require 'spec_helper'
require 'benchmark'

describe Siberite::Client do
  before do
    @queue = "a_queue"
    @client = Siberite::Client.new(*Siberite::Config.default)

    @client.delete(@queue) rescue nil # Memcache::ServerEnd bug
  end

  it "is fast" do
    @client.flush(@queue)
    @value = { :value => "a value" }
    @raw_value = Marshal.dump(@value)

    times = 10_000

    Benchmark.bm do |x|
      x.report("set:") { for i in 1..times; @client.set(@queue, @value); end }
      x.report("get:") { for i in 1..times; @client.get(@queue); end }
      x.report("set (raw):") { for i in 1..times; @client.set(@queue, @raw_value, 0, true); end }
      x.report("get (raw):") { for i in 1..times; @client.get(@queue, :raw => true); end }
    end
  end
end
