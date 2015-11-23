## siberite-client: Talk to Siberite queue server from Ruby

siberite-client is a library that allows you to talk to a [Siberite](http://github.com/robey/siberite) queue server from ruby. As Siberite uses the memcache protocol, siberite-client is implemented as a wrapper around the memcached gem.


## Installation

you will need to install memcached.gem, though rubygems should do this for you. just:

    sudo gem install siberite-client


## Basic Usage

`Siberite::Client.new` takes a list of servers and an options hash. See the [rdoc for Memcached](http://blog.evanweaver.com/files/doc/fauna/memcached/classes/Memcached.html) for an explanation of what the various options do.

    require 'siberite'

    $queue = Siberite::Client.new('localhost:22133')
    $queue.set('a_queue', 'foo')
    $queue.get('a_queue') # => 'foo'


## Client Proxies

siberite-client comes with a number of decorators that change the behavior of the raw client.

    $queue = Siberite::Client.new('localhost:22133')
    $queue.get('empty_queue') # => nil

    $queue = Siberite::Client::Blocking.new(Siberite::Client.new('localhost:22133'))
    $queue.get('empty_queue') # does not return until it pulls something from the queue


## Configuration Management

Siberite::Config provides some tools for pulling queue config out of a YAML config file.

    Siberite::Config.load 'path/to/siberite.yml'
    Siberite::Config.environment = 'production' # defaults to development

    $queue = Siberite::Config.new_client

This tells siberite-client to look for `path/to/siberite.yml`, and pull the client configuration out of
the 'production' key in that file. Sample config:

    defaults: &defaults
      distribution: :random
      timeout: 2
      connect_timeout: 1

    production:
      <<: *defaults
      servers:
        - siberite01.example.com:22133
        - siberite02.example.com:22133
        - siberite03.example.com:22133

    development:
      <<: *defaults
      servers:
        - localhost:22133
      show_backtraces: true
