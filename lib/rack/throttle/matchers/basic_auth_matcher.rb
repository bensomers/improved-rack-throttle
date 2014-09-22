require 'rack/throttle/matchers/matcher'
require 'base64'

module Rack; module Throttle
  ###
  # BasicAuthMatchers are used to restrict requests based on the Basic Auth user name used in the
  # request. For instance, you may care about limiting requests
  # to a machine-consumed API, but not be concerned about requests
  # coming from browsers.
  # BasicAuthMatchers take Regexp object to matcha gainst the request path.
  #
  class BasicAuthMatcher < Matcher
    ###
    # @param [Rack::Request] request
    # @return [Boolean]
    def match?(request)
      username = extract_username(request.env['HTTP_AUTHORIZATION'])
      !!(@rule =~ username)
    end

    ###
    # @return [String]
    def identifier
      "basic_auth-" + @rule.inspect
    end

    ###
    # @param [String] Contents of HTTP_AUTHORIZATION header, e.g. 'Basic dXNlcjpwYXNzd29yZA==\n'
    # @return [String]
    def extract_username(string)
      return nil if string.nil? || string.empty?
      basic, b64 = string.split(' ')
      Base64.decode64(b64).split(':').first if basic =~ /basic/i
    end

  end

end; end

