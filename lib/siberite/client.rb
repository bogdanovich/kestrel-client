require 'forwardable'

module Siberite
  class Client
    require 'siberite/client/stats_helper'

    autoload :Proxy, 'siberite/client/proxy'
    autoload :Envelope, 'siberite/client/envelope'
    autoload :Blocking, 'siberite/client/blocking'
    autoload :Partitioning, 'siberite/client/partitioning'
    autoload :Unmarshal, 'siberite/client/unmarshal'
    autoload :Namespace, 'siberite/client/namespace'
    autoload :Json, 'siberite/client/json'
    autoload :Transactional, "siberite/client/transactional"

    SIBERITE_OPTIONS = [:gets_per_server, :exception_retry_limit, :get_timeout_ms].freeze

    DEFAULT_OPTIONS = {
      :retry_timeout => 0,
      :exception_retry_limit => 5,
      :timeout => 0.25,
      :gets_per_server => 100,
      :get_timeout_ms => 10
    }.freeze

    # Exceptions which are connection failures we retry after
    RECOVERABLE_ERRORS = [
      Memcached::ServerIsMarkedDead,
      Memcached::ATimeoutOccurred,
      Memcached::ConnectionBindFailure,
      Memcached::ConnectionFailure,
      Memcached::ConnectionSocketCreateFailure,
      Memcached::Failure,
      Memcached::MemoryAllocationFailure,
      Memcached::ReadFailure,
      Memcached::ServerError,
      Memcached::SystemError,
      Memcached::UnknownReadFailure,
      Memcached::WriteFailure,
      Memcached::NotFound
    ]

    extend Forwardable
    include StatsHelper

    attr_accessor :servers, :options
    attr_reader :current_queue, :siberite_options, :current_server

    def_delegators :@write_client, :add, :append, :cas, :decr, :incr, :get_orig, :prepend

    def initialize(*servers)
      opts = servers.last.is_a?(Hash) ? servers.pop : {}
      opts = DEFAULT_OPTIONS.merge(opts)

      @siberite_options = extract_siberite_options!(opts)
      @default_get_timeout = siberite_options[:get_timeout_ms]
      @gets_per_server = siberite_options[:gets_per_server]
      @exception_retry_limit = siberite_options[:exception_retry_limit]
      @counter = 0
      @shuffle = true

      # we handle our own retries so that we can apply different
      # policies to sets and gets, so set memcached limit to 0
      opts[:exception_retry_limit] = 0
      opts[:distribution] = :random # force random distribution

      self.servers  = Array(servers).flatten.compact
      self.options  = opts

      @server_count = self.servers.size # Minor optimization.
      @read_client  = Memcached.new(self.servers[rand(@server_count)], opts)
      @write_client = Memcached.new(self.servers[rand(@server_count)], opts)
    end

    def delete(key, expiry=0)
      with_retries { @write_client.delete key }
    rescue Memcached::NotFound, Memcached::ServerEnd
    end

    def set(key, value, ttl=0, raw=false)
      with_retries { @write_client.set key, value, ttl, !raw }
      true
    rescue Memcached::NotStored
      false
    end

    # This provides the necessary semantic to support transactionality
    # in the Transactional client. It temporarily disables server
    # shuffling to allow the client to close any open transactions on
    # the current server before jumping.
    #
    def get_from_last(*args)
      @shuffle = false
      get *args
    ensure
      @shuffle = true
    end

    # ==== Parameters
    # key<String>:: Queue name
    # opts<Boolean,Hash>:: True/false toggles Marshalling. A Hash
    #                      allows collision-avoiding options support.
    #
    # ==== Options (opts)
    # :open<Boolean>:: Begins a transactional read.
    # :close<Boolean>:: Ends a transactional read.
    # :abort<Boolean>:: Cancels an existing transactional read
    # :peek<Boolean>:: Return the head of the queue, without removal
    # :timeout<Integer>:: Milliseconds to block for a new item
    # :raw<Boolean>:: Toggles Marshalling. Equivalent to the "old
    #                 style" second argument.
    #
    def get(key, opts = {})
      raw = opts[:raw] || false
      commands = extract_queue_commands(opts)

      val =
        begin
          shuffle_if_necessary! key
          @read_client.get key + commands, !raw
        rescue *RECOVERABLE_ERRORS
          # we can't tell the difference between a server being down
          # and an empty queue, so just return nil. our sticky server
          # logic should eliminate piling on down servers
          nil
        end

      # nil result without :close and :abort, force next get to jump from
      # current server
      if !val && @shuffle && !opts[:close] && !opts[:abort]
        @counter = @gets_per_server
      end

      val
    end

    def flush(queue)
      count = 0
      while sizeof(queue) > 0
        count += 1 while get queue, :raw => true
      end
      count
    end

    def peek(queue)
      get queue, :peek => true
    end

    private

    def extract_siberite_options!(opts)
      siberite_opts, memcache_opts = opts.inject([{}, {}]) do |(kestrel, memcache), (key, opt)|
        (SIBERITE_OPTIONS.include?(key) ? kestrel : memcache)[key] = opt
        [kestrel, memcache]
      end
      opts.replace(memcache_opts)
      siberite_opts
    end

    def shuffle_if_necessary!(key)
      return unless @server_count > 1
      # Don't reset servers on the first request:
      # i.e. @counter == 0 && @current_queue == nil
      if @shuffle &&
          (@counter > 0 && key != @current_queue) ||
          @counter >= @gets_per_server
        @counter = 0
        @current_queue = key
        @read_client.reset(servers[rand(@server_count)])
      else
        @counter +=1
      end
    end

    def extract_queue_commands(opts)
      commands = [:open, :close, :abort, :peek].select do |key|
        opts[key]
      end

      if timeout = (opts[:timeout] || @default_get_timeout)
        commands << "t=#{timeout}"
      end

      commands.map { |c| "/#{c}" }.join('')
    end

    def with_retries #:nodoc:
      yield
    rescue *RECOVERABLE_ERRORS
      tries ||= @exception_retry_limit + 1
      tries -= 1
      @write_client.reset(servers[rand(@server_count)])

      if tries > 0
        retry
      else
        raise
      end
    end

  end
end
