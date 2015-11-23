require 'spec_helper'

class Envelope
  class << self; attr_accessor :unwraps end

  def initialize(item); @item = item end
  def unwrap; self.class.unwraps += 1; @item end
end

describe Siberite::Client::Envelope do
  describe "Instance Methods" do
    before do
      Envelope.unwraps = 0
      @raw_client = Siberite::Client.new(*Siberite::Config.default)
      @client = Siberite::Client::Envelope.new(Envelope, @raw_client)
    end

    describe "#get and #set" do
      describe "envelopes" do
        it "integrates" do
          @client.set("a_queue", :mcguffin)
          @client.get("a_queue").should == :mcguffin
          Envelope.unwraps.should == 1
        end

        it "creates an envelope on a set" do
          mock(Envelope).new(:mcguffin)
          @client.set('a_queue', :mcguffin)
        end

        it "unwraps an envelope on a get" do
          envelope = Envelope.new(:mcguffin)
          mock(@raw_client).get('a_queue') { envelope }
          mock.proxy(envelope).unwrap
          @client.get('a_queue').should == :mcguffin
        end

        it "does not unwrap a nil get" do
          mock(@raw_client).get('a_queue') { nil }
          @client.get('a_queue').should be_nil
        end
      end
    end
  end
end
