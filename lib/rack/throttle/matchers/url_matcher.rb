module Rack; module Throttle
  ###
  # UrlMatchers are used to restrict requests based on the URL
  # requested. For instance, you may care about limiting requests
  # to a machine-consumed API, but not be concerned about requests
  # coming from browsers.
  # UrlMatchers take Regexp object to match against the request path.
  class UrlMatcher < Matcher
    ###
    # @param [Rack::Request] request
    # @return [Boolean]
    def match?(request)
      !!(@rule =~ request.path)
    end

    ###
    # @return [String]
    def identifier
      "url-" + @rule.inspect
    end
  end

end; end

