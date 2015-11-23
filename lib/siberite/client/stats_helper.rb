module Siberite::Client::StatsHelper
  STATS_TIMEOUT    = 3
  QUEUE_STAT_NAMES = %w{items open_transactions}

  def sizeof(queue)
    stat_info = stat(queue)
    stat_info ? stat_info['items'] : 0
  end

  def available_queues
    stats['queues'].keys.sort
  end

  def stats
    alive, dead = 0, 0

    results = servers.map do |server|
      begin
        result = stats_for_server(server)
        alive += 1
        result
      rescue Exception
        dead += 1
        nil
      end
    end.compact

    stats = merge_stats(results)
    stats['alive_servers'] = alive
    stats['dead_servers']  = dead
    stats
  end

  def stat(queue)
    stats['queues'][queue]
  end

  private

  def stats_for_server(server)
    server_name, port = server.split(/:/)
    socket = nil
    with_timeout STATS_TIMEOUT do
      socket = TCPSocket.new(server_name, port)
    end
    socket.puts "STATS"

    stats = Hash.new
    stats['queues'] = Hash.new
    while line = socket.readline
      if line =~ /^STAT queue_(\S+?)_(#{QUEUE_STAT_NAMES.join("|")}) (\S+)/
        queue_name, queue_stat_name, queue_stat_value = $1, $2, deserialize_stat_value($3)
        stats['queues'][queue_name] ||= Hash.new
        stats['queues'][queue_name][queue_stat_name] = queue_stat_value
      elsif line =~ /^STAT (\w+) (\S+)/
        stat_name, stat_value = $1, deserialize_stat_value($2)
        stats[stat_name] = stat_value
      elsif line =~ /^END/
        socket.close
        break
      elsif defined?(RAILS_DEFAULT_LOGGER)
        RAILS_DEFAULT_LOGGER.debug("SiberiteClient#stats_for_server: Ignoring #{line}")
      end
    end

    stats
  ensure
    socket.close if socket && !socket.closed?
  end

  def merge_stats(all_stats)
    result = Hash.new

    all_stats.each do |stats|
      stats.each do |stat_name, stat_value|
        if result.has_key?(stat_name)
          if stat_value.kind_of?(Hash)
            result[stat_name] = merge_stats([result[stat_name], stat_value])
          else
            result[stat_name] += stat_value
          end
        else
          result[stat_name] = stat_value
        end
      end
    end

    result
  end

  def deserialize_stat_value(value)
    case value
    when /^\d+\.\d+$/
        value.to_f
    when /^\d+$/
        value.to_i
    else
      value
    end
  end

  begin
    require "system_timer"

    def with_timeout(seconds, &block)
      SystemTimer.timeout_after(seconds, &block)
    end

  rescue LoadError
    if ! defined?(RUBY_ENGINE)
      # MRI 1.8, all other interpreters define RUBY_ENGINE, JRuby and
      # Rubinius should have no issues with timeout.
      warn "WARNING: using the built-in Timeout class which is known to have issues when used for opening connections. Install the SystemTimer gem if you want to make sure the Siberite client will not hang."
    end

    require "timeout"

    def with_timeout(seconds, &block)
      Timeout.timeout(seconds, &block)
    end
  end
end
