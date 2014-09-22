HTTP Request Rate Limiter for Rack Applications
===============================================

[![Code Climate](https://codeclimate.com/badge.png)](https://codeclimate.com/github/bensomers/improved-rack-throttle)
[![Dependency Status](https://gemnasium.com/bensomers/improved-rack-throttle.png)](https://gemnasium.com/bensomers/improved-rack-throttle)
[![Build Status](https://travis-ci.org/bensomers/improved-rack-throttle.png?branch=master)](https://travis-ci.org/bensomers/improved-rack-throttle)

This is a [Rack][] middleware that provides logic for rate-limiting incoming
HTTP requests to Rack applications. You can use `Rack::Throttle` with any
Ruby web framework based on Rack, including with Ruby on Rails 3.0 and with
Sinatra.

* <http://github.com/bensomers/improved-rack-throttle>

Features
--------

* Throttles a Rack application by enforcing a minimum time interval between
  subsequent HTTP requests from a particular client, as well as by defining
  a maximum number of allowed HTTP requests per a given time period (hourly
  or daily).
* Scopes throttling rules by request path, http method, or user_agent
  for applications that need a variety of rules
* Compatible with any Rack application and any Rack-based framework.
* Stores rate-limiting counters in any key/value store implementation that
  responds to `#[]`/`#[]=` (like Ruby's hashes) or to `#get`/`#set` (like
  memcached or Redis). This makes it easy to use global counters across
  multiple web servers.
* Compatible with the [gdbm][] binding included in Ruby's standard library.
* Compatible with the [memcached][], [memcache-client][], [memcache][] and
  [redis][] gems.
* Compatible with [Heroku][]'s [memcached add-on][Heroku memcache]

Examples
--------

### Adding throttling to a Rails 3.x application

    # config/application.rb
    require 'rack/throttle'

    class Application < Rails::Application
      config.middleware.use Rack::Throttle::Interval
    end

### Adding throttling to a Sinatra application

    #!/usr/bin/env ruby -rubygems
    require 'sinatra'
    require 'rack/throttle'

    use Rack::Throttle::Interval

    get('/hello') { "Hello, world!\n" }

### Adding throttling to a Rackup application

    #!/usr/bin/env rackup
    require 'rack/throttle'

    use Rack::Throttle::Interval

    run lambda { |env| [200, {'Content-Type' => 'text/plain'}, "Hello, world!\n"] }

### Enforcing a minimum 3-second interval between requests

    use Rack::Throttle::Interval, :min => 3.0

### Allowing a maximum of 100 requests per hour, for the foo basic auth
user

    use Rack::Throttle::Hourly,   :max => 100, :rules => {:basic_auth =>
/foo/}

### Allowing a maximum of 100 requests per hour

    use Rack::Throttle::Hourly,   :max => 100

### Allowing a maximum of 1,000 requests per day

    use Rack::Throttle::Daily,    :max => 1000

### Allowing 1 request per second, with bursts of up to 5 requests

    use Rack::Throttle::SlidingWindow, :average => 1, :burst => 5

### Combining various throttling constraints into one overall policy

    use Rack::Throttle::Daily,    :max => 1000  # requests
    use Rack::Throttle::Hourly,   :max => 100   # requests
    use Rack::Throttle::Interval, :min => 3.0   # seconds

### Storing the rate-limiting counters in a GDBM database

    require 'gdbm'

    use Rack::Throttle::Interval, :cache => GDBM.new('tmp/throttle.db')

### Storing the rate-limiting counters on a Memcached server

    require 'memcached'

    use Rack::Throttle::Interval, :cache => Memcached.new, :key_prefix => :throttle

### Storing the rate-limiting counters on a Redis server

    require 'redis'

    use Rack::Throttle::Interval, :cache => Redis.new, :key_prefix => :throttle

### Scoping the rate-limit to a specific path and method

    use Rack::Throttle::Interval, :rules => {:url => /api/, :method => :post}

Throttling Strategies
---------------------

`Rack::Throttle` supports four built-in throttling strategies:

* `Rack::Throttle::Interval`: Throttles the application by enforcing a
  minimum interval (by default, 1 second) between subsequent HTTP requests.
* `Rack::Throttle::Hourly`: Throttles the application by defining a
  maximum number of allowed HTTP requests per hour (by default, 3,600
  requests per 60 minutes, which works out to an average of 1 request per
  second).
* `Rack::Throttle::Daily`: Throttles the application by defining a
  maximum number of allowed HTTP requests per day (by default, 86,400
  requests per 24 hours, which works out to an average of 1 request per
  second).
* `Rack::Throttle::SlidingWindow`: Throttles the application by defining
  an average request rate, and a burst allowance that clients can hit
  (as long as they stay within the average). By default, this is 1
  request per second, with bursts of up to 5 requests at a time. Users
  who exceed the average and who have used up their burst will have all
  of their requests denied until they comply with the policy.

You can fully customize the implementation details of any of these strategies
by simply subclassing one of the aforementioned default implementations.
And, of course, should your application-specific requirements be
significantly more complex than what we've provided for, you can also define
entirely new kinds of throttling strategies by subclassing the
`Rack::Throttle::Limiter` base class directly.

Scoping Rules
-------------
Rack::Throttle ships with a Rack::Throttle::Matcher base class, and three
implementations. Rack::Throttle::UrlMatcher and
Rack::Throttle::UserAgentMatcher allow you to pass in regular expressions
for request path and user agent, while Rack::Throttle::MethodMatcher
will filter by request method when passed a Symbol :get, :post, :put, or
:delete. These rules are additive, so you can throttle just POST
requests to your '/login' page, for example.


HTTP Client Identification
--------------------------

The rate-limiting counters stored and maintained by `Rack::Throttle` are
keyed to unique HTTP clients.

By default, HTTP clients are uniquely identified by their IP address as
returned by `Rack::Request#ip`. If you wish to instead use a more granular,
application-specific identifier such as a session key or a user account
name, you can subclass a throttling strategy implementation and
override the `#client_identifier` method.

HTTP Response Codes and Headers
-------------------------------

### 403 Forbidden (Rate Limit Exceeded)

When a client exceeds their rate limit, `Rack::Throttle` by default returns
a "403 Forbidden" response with an associated "Rate Limit Exceeded" message
in the response body.

An HTTP 403 response means that the server understood the request, but is
refusing to respond to it and an accompanying message will explain why.
This indicates an error on the client's part in exceeding the rate limits
outlined in the acceptable use policy for the site, service, or API.

### 503 Service Unavailable (Rate Limit Exceeded)

However, there exists a widespread practice of instead returning a "503
Service Unavailable" response when a client exceeds the set rate limits.
This is technically dubious because it indicates an error on the server's
part, which is certainly not the case with rate limiting - it was the client
that committed the oops, not the server.

An HTTP 503 response would be correct in situations where the server was
genuinely overloaded and couldn't handle more requests, but for rate
limiting an HTTP 403 response is more appropriate. Nonetheless, if you think
otherwise, `Rack::Throttle` does allow you to override the returned HTTP
status code by passing in a `:code => 503` option when constructing a
`Rack::Throttle::Limiter` instance.

Documentation
-------------
<http://rubydoc.info/gems/improved-rack-throttle>

* {Rack::Throttle}
  * {Rack::Throttle::Interval}
  * {Rack::Throttle::Daily}
  * {Rack::Throttle::Hourly}
  * {Rack::Throttle::SlidingWindow}
  * {Rack::Throttle::Matcher}
  * {Rack::Throttle::MethodMatcher}
  * {Rack::Throttle::UrlMatcher}
  * {Rack::Throttle::UserAgentMatcher}
  * {Rack::Throttle::BasicAuthMatcher}

Dependencies
------------

* [Rack](http://rubygems.org/gems/rack) (>= 1.0.0)

Installation
------------

The recommended installation method is via [RubyGems](http://rubygems.org/).
To install the latest official release of the gem, do:

    % [sudo] gem install improved-rack-throttle

Download
--------

To get a local working copy of the development repository, do:

    % git clone git://github.com/bensomers/improved-rack-throttle.git

Alternatively, you can download the latest development version as a tarball
as follows:

    % wget http://github.com/bensomers/improved-rack-throttle/tarball/master

Authors
-------
* [Ben Somers](mailto:somers.ben@gmail.com) - <http://www.github.com/bensomers>
* [Arto Bendiken](mailto:arto.bendiken@gmail.com) - <http://ar.to/>
* [Brendon Murphy](mailto:disposable.20.xternal@spamourmet.com>) - <http://www.techfreak.net/>

License
-------

`Rack::Throttle` is free and unencumbered public domain software. For more
information, see <http://unlicense.org/> or the accompanying UNLICENSE file.

[Rack]:            http://rack.rubyforge.org/
[gdbm]:            http://ruby-doc.org/stdlib/libdoc/gdbm/rdoc/classes/GDBM.html
[memcached]:       http://rubygems.org/gems/memcached
[memcache-client]: http://rubygems.org/gems/memcache-client
[memcache]:        http://rubygems.org/gems/memcache
[redis]:           http://rubygems.org/gems/redis
[Heroku]:          http://heroku.com/
[Heroku memcache]: http://docs.heroku.com/memcache

Support
-------

Recent work on improved-rack-throttle has been funded by Rafter, Inc.
