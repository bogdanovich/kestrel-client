require 'spec_helper'

describe "Siberite::Client::Transactional" do
   before do
     @raw_client = Siberite::Client.new(*Siberite::Config.default)
     @client = Siberite::Client::Transactional.new(@raw_client)
     @queue = "some_queue"
   end

   describe "integration" do
    def get_job
      job = nil
      job = @client.get(@queue) until job
      job
    end

    it "processes normal jobs" do
      returns = [:mcguffin]
      stub(@raw_client).get(@queue, anything) { returns.shift }
      stub(@raw_client).get_from_last(@queue + "_errors", anything)

      mock(@raw_client).get_from_last(@queue, :close => true)

      get_job.should == :mcguffin
      @client.current_try.should == 1
      @client.get(@queue) # simulate next get run
    end

    it "processes successful retries" do
      returns = [Siberite::Client::Transactional::RetryableJob.new(1, :mcguffin)]
      stub(@raw_client).get_from_last(@queue + "_errors", anything) { returns.shift }
      stub(@raw_client).get(@queue, anything)

      mock(@raw_client).get_from_last(@queue + "_errors", :close => true)

      get_job.should == :mcguffin
      @client.current_try.should == 2
      @client.get(@queue) # simulate next get run
    end

    it "processes normal jobs that should retry" do
      returns = [:mcguffin]
      stub(@raw_client).get(@queue, anything) { returns.shift }
      stub(@raw_client).get_from_last(@queue + "_errors", anything)

      mock(@raw_client).set(@queue + "_errors", anything) do |q,j|
        j.retries.should == 1
        j.job.should == :mcguffin
      end
      mock(@raw_client).get_from_last(@queue, :close => true)

      get_job.should == :mcguffin
      @client.current_try.should == 1

      @client.retry
      @client.get(@queue) # simulate next get run
    end

    it "processes retries that should retry" do
      returns = [Siberite::Client::Transactional::RetryableJob.new(1, :mcguffin)]
      stub(@raw_client).get_from_last(@queue + "_errors", :open => true) { returns.shift }
      stub(@raw_client).get(@queue, anything)
      mock(@raw_client).set(@queue + "_errors", anything) do |q,j|
        j.retries.should == 2
        j.job.should == :mcguffin
      end
      mock(@raw_client).get_from_last(@queue + "_errors", :close => true)

      get_job.should == :mcguffin
      @client.current_try.should == 2

      @client.retry
      @client.get(@queue) # simulate next get run
    end

    it "processes retries that should give up" do
      returns = [Siberite::Client::Transactional::RetryableJob.new(Siberite::Client::Transactional::DEFAULT_RETRIES - 1, :mcguffin)]
      stub(@raw_client).get_from_last(@queue + "_errors", :open => true) { returns.shift }
      stub(@raw_client).get(@queue, anything)
      mock(@raw_client).set.never
      mock(@raw_client).get_from_last(@queue + "_errors", :close => true)

      get_job.should == :mcguffin
      @client.current_try.should == Siberite::Client::Transactional::DEFAULT_RETRIES

      lambda { @client.retry }.should raise_error(Siberite::Client::Transactional::RetriesExceeded)
      @client.get(@queue) # simulate next get run
    end
  end

  describe "Instance Methods" do
    before do
      stub(@client).rand { 1 }
    end

    describe "#get" do
      it "asks for a transaction" do
        mock(@raw_client).get(@queue, :open => true) { :mcguffin }
        @client.get(@queue).should == :mcguffin
      end

      it "is nil when the primary queue is empty and selected" do
        mock(@client).rand { Siberite::Client::Transactional::ERROR_PROCESSING_RATE + 0.05 }
        mock(@raw_client).get(@queue, anything) { nil }
        mock(@raw_client).get(@queue + "_errors", :open => true).never
        @client.get(@queue).should be_nil
      end

      it "is nil when the error queue is empty and selected" do
        mock(@client).rand { Siberite::Client::Transactional::ERROR_PROCESSING_RATE - 0.05 }
        mock(@raw_client).get(@queue, anything).never
        mock(@raw_client).get_from_last(@queue + "_errors", :open => true) { nil }
        @client.get(@queue).should be_nil
      end

      it "returns the payload of a RetryableJob" do
        stub(@client).rand { 0 }
        mock(@raw_client).get_from_last(@queue + "_errors", anything) do
          Siberite::Client::Transactional::RetryableJob.new(1, :mcmuffin)
        end

        @client.get(@queue).should == :mcmuffin
      end

      it "closes an open transaction with no retries" do
        stub(@raw_client).get(@queue, anything) { :mcguffin }
        @client.get(@queue)

        mock(@raw_client).get_from_last(@queue, :close => true)
        @client.get(@queue)
      end

      it "closes an open transaction with retries" do
        stub(@client).rand { 0 }
        stub(@raw_client).get_from_last(@queue + "_errors", :open => true) do
          Siberite::Client::Transactional::RetryableJob.new(1, :mcmuffin)
        end
        @client.get(@queue)

        mock(@raw_client).get_from_last(@queue + "_errors", :close => true)
        @client.get(@queue)
      end

      it "prevents transactional gets across multiple queues" do
        stub(@raw_client).get(@queue, anything) { :mcguffin }
        @client.get(@queue)

        lambda do
          @client.get("transaction_fail")
        end.should raise_error(Siberite::Client::Transactional::MultipleQueueException)
      end
    end

    describe "#retry" do
      before do
        stub(@raw_client).get(@queue, anything) { :mcmuffin }
        stub(@raw_client).get_from_last
        @client.get(@queue)
      end

      it "raises an exception if called when there is no open transaction" do
        @client.close_last_transaction
        lambda { @client.retry }.should raise_error(Siberite::Client::Transactional::NoOpenTransaction)
      end

      it "raises an exception if retry has already been called" do
        @client.retry
        lambda { @client.retry }.should raise_error(Siberite::Client::Transactional::NoOpenTransaction)
      end

      it "enqueues a fresh failed job to the errors queue with a retry count" do
        mock(@raw_client).set(@queue + "_errors", anything) do |queue, job|
          job.retries.should == 1
          job.job.should == :mcmuffin
        end
        @client.retry.should be_truthy
      end

      it "allows specification of the job to retry" do
        mock(@raw_client).set(@queue + "_errors", anything) do |queue, job|
          job.retries.should == 1
          job.job.should == :revised_mcmuffin
        end
        @client.retry(:revised_mcmuffin).should be_truthy
      end

      it "increments the retry count and re-enqueues the retried job" do
        stub(@client).rand { 0 }
        stub(@raw_client).get_from_last(@queue + "_errors", anything) do
          Siberite::Client::Transactional::RetryableJob.new(1, :mcmuffin)
        end

        mock(@raw_client).set(@queue + "_errors", anything) do |queue, job|
          job.retries.should == 2
          job.job.should == :mcmuffin
        end

        @client.get(@queue)
        @client.retry.should be_truthy
      end

      it "does not enqueue the retried job after too many tries" do
        stub(@client).rand { 0 }
        stub(@raw_client).get_from_last(@queue + "_errors", :open => true) do
          Siberite::Client::Transactional::RetryableJob.new(Siberite::Client::Transactional::DEFAULT_RETRIES - 1, :mcmuffin)
        end
        mock(@raw_client).set(@queue + "_errors", anything).never
        mock(@raw_client).get_from_last(@queue + "_errors", :close => true)
        @client.get(@queue)
        lambda { @client.retry }.should raise_error(Siberite::Client::Transactional::RetriesExceeded)
      end

      it "closes an open transaction with no retries" do
        stub(@raw_client).get(@queue, anything) { :mcguffin }
        @client.get(@queue)

        mock(@raw_client).get_from_last(@queue, :close => true)
        @client.retry
      end

      it "closes an open transaction with retries" do
        stub(@client).rand { 0 }
        stub(@raw_client).get_from_last(@queue + "_errors", :open => true) do
          Siberite::Client::Transactional::RetryableJob.new(1, :mcmuffin)
        end
        @client.get(@queue)

        mock(@raw_client).get_from_last(@queue + "_errors", :close => true)
        @client.retry
      end
    end

    describe "#read_from_error_queue?" do
      it "returns the error queue ERROR_PROCESSING_RATE pct. of the time" do
        mock(@client).rand { Siberite::Client::Transactional::ERROR_PROCESSING_RATE - 0.05 }
        @client.send(:read_from_error_queue?).should == true
      end

      it "returns the normal queue most of the time" do
        mock(@client).rand { Siberite::Client::Transactional::ERROR_PROCESSING_RATE + 0.05 }
        @client.send(:read_from_error_queue?).should == false
      end
    end

    describe "#close_last_transaction" do
      it "does nothing if there is no last transaction" do
        mock(@raw_client).get_from_last(@queue, :close => true).never
        mock(@raw_client).get_from_last(@queue + "_errors", :close => true).never
        @client.send(:close_last_transaction)
      end

      it "closes the normal queue if the job was pulled off of the normal queue" do
        mock(@client).read_from_error_queue? { false }
        mock(@raw_client).get(@queue, :open => true) { :mcguffin }
        mock(@raw_client).get_from_last(@queue, :close => true)
        mock(@raw_client).get_from_last(@queue + "_errors", :close => true).never

        @client.get(@queue).should == :mcguffin
        @client.send(:close_last_transaction)
      end

      it "closes the error queue if the job was pulled off of the error queue" do
        mock(@client).read_from_error_queue? { true }
        mock(@raw_client).get_from_last(@queue + "_errors", :open => true) { Siberite::Client::Transactional::RetryableJob.new 1, :mcguffin }
        mock(@raw_client).get_from_last(@queue, :close => true).never
        mock(@raw_client).get_from_last(@queue + "_errors", :close => true)

        @client.get(@queue).should == :mcguffin
        @client.send(:close_last_transaction)
      end
    end
  end
end
