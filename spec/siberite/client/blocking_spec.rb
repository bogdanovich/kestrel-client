require 'spec_helper'

describe "Siberite::Client::Blocking" do
  describe "Instance Methods" do
    before do
      @raw_client = Siberite::Client.new(*Siberite::Config.default)
      @client = Siberite::Client::Blocking.new(@raw_client)
    end

    describe "#get" do
      before do
        @queue = "some_queue"
      end

      it "blocks on a get until the get works" do
        mock(@raw_client).
          get(@queue) { nil }.times(5).then.get(@queue) { :mcguffin }
        @client.get(@queue).should == :mcguffin
      end

      describe "#get_without_blocking" do
        it "does not block" do
          mock(@raw_client).get(@queue) { nil }
          @client.get_without_blocking(@queue).should be_nil
        end
      end
    end
  end
end
