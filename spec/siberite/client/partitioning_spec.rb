require 'spec_helper'

describe Siberite::Client::Partitioning do
  before do
    @client_1 = Siberite::Client.new(*Siberite::Config.default)
    @client_2 = Siberite::Client.new(*Siberite::Config.default)
    @default_client = Siberite::Client.new(*Siberite::Config.default)

    @client = Siberite::Client::Partitioning.new(
        'queue1' => @client_1,
        ['queue2', 'queue3'] => @client_2,
        default: @default_client
    )
  end

  %w(set get delete flush stat).each do |method|
    describe "##{method}" do
      it "routes to the correct client" do
        mock(@client_1).__send__(method, 'queue1')
        @client.send(method, 'queue1')

        mock(@client_2).__send__(method, 'queue2')
        @client.send(method, 'queue2')

        mock(@client_2).__send__(method, 'queue3/queue_arg')
        @client.send(method, 'queue3/queue_arg')

        mock(@default_client).__send__(method, 'queue4')
        @client.send(method, 'queue4')
      end
    end
  end
end
