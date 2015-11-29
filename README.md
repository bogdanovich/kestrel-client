[![License][License-Image]][License-Url] [![Build][Build-Status-Image]][Build-Status-Url] [![Gem Version][Gem-Image]][Gem-Url]
## Talk to Siberite queue server from Ruby

Siberite-client is a library that allows you to talk to a [Siberite](http://github.com/bogdanovich/siberite) queue server from ruby.
As Siberite uses the memcache protocol, siberite-client is implemented as a wrapper around the memcached gem.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'siberite-client'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install siberite-client

## Basic Usage

`Siberite::Client.new` takes a list of servers and an options hash.
See the [rdoc for Memcached](http://blog.evanweaver.com/files/doc/fauna/memcached/classes/Memcached.html) for an explanation of what the various options do.

```ruby
require 'siberite'

queue = Siberite::Client.new('localhost:22133')
queue.set('a_queue', 'foo')
queue.set('a_queue', 'bar')
queue.set('a_queue', 'baz')

queue.get('a_queue') # => 'foo'

# opens a reliable read
queue.get_open('a_queue') # => 'bar'
queue.get_close('a_queue')

# acknowledges previously opened read and opens a new one)
queue.get_close_open('a_queue') # => 'baz'

# multiple consumer groups
queue.set('a_queue', 'foo')
queue.set('a_queue', 'bar')

queue.get('a_queue', group: "group_1") # => 'foo'
queue.get('a_queue', group: "group_2") # => 'foo'

queue.get('a_queue', group: "group_1") # => 'bar'
queue.get('a_queue', group: "group_2") # => 'bar'


# raw format, skip marshaling
queue.set('a_queue', [1,2,3].to_json, 0, raw: true)
queue.get('a_queue', raw: true) # => "[1,2,3]"
```

## Client Proxies

siberite-client comes with a number of decorators that change the behavior of the raw client.

```ruby
client = Siberite::Client.new('localhost:22133')
client.get('empty_queue') # => nil

# Blocking client
queue = Siberite::Client::Blocking.new(client)
queue.get('empty_queue') # does not return until it pulls something from the queue

# Namespaced client
queue = Siberite::Client::Namespace.new('foo', client)
queue.set('work', 1) # adds message to foo:work queue

# Partitioned client
client_1 = Siberite::Client.new('siberite01.example.com:22133')
client_2 = Siberite::Client.new('siberite02.example.com:22133')
default_client = Siberite::Client.new('siberite03.example.com:22133')

client = Siberite::Client::Partitioning.new(
    'queue1' => client_1,
    ['queue2', 'queue3'] => client_2,
    default: default_client
)
```


## Configuration Management

Siberite::Config provides some tools for pulling queue config out of a YAML config file.

```ruby
Siberite::Config.load 'path/to/siberite.yml'
Siberite::Config.environment = 'production' # defaults to development

queue = Siberite::Config.new_client
```

This tells siberite-client to look for `path/to/siberite.yml`, and pull the client configuration out of
the 'production' key in that file. Sample config:

```yaml
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
```

[License-Url]: http://opensource.org/licenses/Apache-2.0
[License-Image]: https://img.shields.io/hexpm/l/plug.svg
[Build-Status-Url]: https://travis-ci.org/bogdanovich/siberite-ruby
[Build-Status-Image]: https://travis-ci.org/bogdanovich/siberite-ruby.svg?branch=master
[Gem-Image]: https://badge.fury.io/rb/siberite-client.svg
[Gem-Url]: https://rubygems.org/gems/siberite-client
