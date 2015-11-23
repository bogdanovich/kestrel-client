require 'spec_helper'

describe Siberite::Client::Namespace do
  describe "Instance Methods" do
    before do
      @raw_client = Siberite::Client.new(*Siberite::Config.default)
      @client = Siberite::Client::Namespace.new('some_namespace', @raw_client)
    end

    describe "#set" do
      it "prepends a namespace to the key" do
        mock(@raw_client).set('some_namespace:a_queue', :mcguffin)
        @client.set('a_queue', :mcguffin)
      end
    end

    describe "#get" do
      it "prepends a namespace to the key" do
        mock(@raw_client).get('some_namespace:a_queue')
        @client.get('a_queue')
      end
    end

    describe "#delete" do
      it "prepends a namespace to the key" do
        mock(@raw_client).delete('some_namespace:a_queue')
        @client.delete('a_queue')
      end
    end

    describe "#flush" do
      it "prepends a namespace to the key" do
        mock(@raw_client).flush('some_namespace:a_queue')
        @client.flush('a_queue')
      end
    end

    describe "#stat" do
      it "prepends a namespace to the key" do
        mock(@raw_client).stat('some_namespace:a_queue')
        @client.stat('a_queue')
      end
    end

    describe "#available_queues" do
      it "only returns namespaced queues" do
        @raw_client.set('some_namespace:namespaced_queue', 'foo')
        @raw_client.set('unnamespaced_queue', 'foo')

        @client.available_queues.should == ['namespaced_queue']
      end
    end
  end
end
