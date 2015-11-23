require 'spec_helper'

describe Siberite::Client do
  describe "Instance Methods" do
    before do
      @client = Siberite::Client.new('localhost:22133')
    end

    describe "#get and #set" do
      it "basic operation" do
        @client.flush(queue = "test_queue")
        @client.set(queue, value = "russell's reserve")
        @client.get(queue).should == value
      end

      it "returns nil when getting from a queue that does not exist" do
        @client.get('nonexistent_queue').should == nil
      end

      it "gets from the same server :gets_per_server times" do
        client = @client.instance_variable_get(:@read_client)
        mock(client).get("a_queue/t=10", true).times(102).returns('item')

        102.times { @client.get("a_queue") }
      end

      it "gets from a different server when the last result was nil" do
        client = @client.instance_variable_get(:@read_client)
        mock(client).get("a_queue/t=10", true).returns(nil).twice

        2.times { @client.get("a_queue") }
      end

      it "returns nil if there is a recoverable exception" do
        mock(@client).shuffle_if_necessary!(@queue) { raise Memcached::SystemError }
        @client.get(@queue).should == nil
      end

      it "raises the exception if the exception is not recoverable" do
        mock(@client).shuffle_if_necessary!(@queue) { raise ArgumentError }
        lambda { @client.get(@queue) }.should raise_error(ArgumentError)
      end
    end

    describe "retry behavior" do
      it "does not retry gets" do
        mock(@client).with_retries.never
        @client.get("a_queue")
      end

      it "retries sets" do
        mock(@client).with_retries
        @client.set("a_queue", "value")
      end
    end

    describe "#flush" do
      before do
        @queue = "some_random_queue_#{Time.now.to_i}_#{rand(10000)}"
      end

      it "counts the number of items flushed and passes each of them to a given block" do
        %w{A B C}.each { |item| @client.set(@queue, item) }
        @client.flush(@queue).should == 3
      end

      it "does not attempt to Marshal load the data being flushed" do
        @client.set(@queue, "some_stuff", 0, true)
        mock(Marshal).load.never
        @client.flush(@queue).should == 1
      end
    end

    describe "#peek" do
      it "should return first item from the queue and reenqueue" do
        @queue = "some_random_queue_#{Time.now.to_i}_#{rand(10000)}"
        @client.set(@queue, "item_1")
        @client.set(@queue, "item_2")
        @client.peek(@queue).should == "item_1"
        @client.sizeof(@queue).should == 2
      end
    end

    describe "#with_retries" do
      it "retries a specified number of times" do
        mock(@client).set(anything, anything) { raise Memcached::SystemError }.times(6)

        lambda do
          @client.send(:with_retries) { @client.set("a_queue", "foo") }
        end.should raise_error(Memcached::SystemError)
      end

      it "does not raise if within the retry limit" do
        mock(@client).set(anything, anything) { raise Memcached::SystemError }.times(5).
          then.set(anything, anything) { true }

        lambda do
          @client.send(:with_retries) { @client.set("a_queue", "foo") }
        end.should_not raise_error
      end

      it "does not catch unknown errors" do
        mock(@client).set(anything, anything) { raise ArgumentError }

        lambda do
          @client.send(:with_retries) { @client.set("a_queue", "foo") }
        end.should raise_error(ArgumentError)
      end
    end

    describe "#stats" do
      it "retrieves stats" do
        @client.set("test-queue-name", 97)

        stats = @client.stats
        %w{uptime time version curr_items total_items bytes curr_connections total_connections
           cmd_get cmd_set get_hits get_misses bytes_read bytes_written queues}.each do |stat|
          stats[stat].should_not be_nil
        end

        stats['queues']["test-queue-name"].should_not be_nil
        Siberite::Client::QUEUE_STAT_NAMES.each do |queue_stat|
          stats['queues']['test-queue-name'][queue_stat].should_not be_nil
        end
      end

      it "merge in stats from all the servers" do
        server = @client.servers.first
        stub(@client).servers { [server] }
        stats_for_one_server = @client.stats

        server = @client.servers.first
        stub(@client).servers { [server] * 2 }
        stats_for_two_servers = @client.stats

        stats_for_two_servers['bytes'].should == 2*stats_for_one_server['bytes']
      end
    end

    describe "#stat" do
      it "get stats for single queue" do
        @client.set(queue = "test-queue-name", 97)
        all_stats = @client.stats
        single_queue_stats = @client.stat(queue).except("age")

        expect(single_queue_stats).to eq all_stats['queues'][queue].except("age")
      end
    end

    describe "#sizeof" do
      before do
        @queue = "some_random_queue_#{Time.now.to_i}_#{rand(10000)}"
      end

      it "reports the size of the queue" do
        100.times { @client.set(@queue, true) }
        @client.sizeof(@queue).should == 100
      end

      it "reports the size of a non-existant queue as 0" do
        queue = "some_random_queue_#{Time.now.to_i}_#{rand(10000)}"
        @client.sizeof(queue).should == 0
      end
    end

    describe "#available_queues" do
      it "returns all the queue names" do
        @client.set("test-queue-name1", 97)
        @client.set("test-queue-name2", 155)
        @client.available_queues.should include('test-queue-name1')
        @client.available_queues.should include('test-queue-name2')
      end
    end
  end
end
