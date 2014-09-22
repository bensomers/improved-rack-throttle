require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe Rack::Throttle::BasicAuthMatcher do
  include Rack::Test::Methods

  def app
    @target_app ||= example_target_app
    @app ||= Rack::Throttle::Limiter.new(@target_app, :rules => {:basic_auth => /foo/})
  end

  it "should not bother checking if the basic auth user doesn't match the rule" do
    authorize "user", "password"
    expect(app).not_to receive(:allowed?)
    get "/bar-auth"
    expect(last_response.body).to show_allowed_response
  end

  it "should check if the user logged in" do
    authorize "foo", "foo"
    expect(app).to receive(:allowed?).and_return(true)
    get "/foo-auth"
    expect(last_response.body).to show_allowed_response
  end

  it "should not bother checking if no basic auth was attempted" do
    expect(app).not_to receive(:allowed?)
    get "/bar-no-auth"
    expect(last_response.body).to show_allowed_response
  end

  it "should append the rule to the cache key" do
    get "/foo-no-auth"
    expect(app.send(:cache_key, last_request)).to eq "127.0.0.1:basic_auth-/foo/"
  end

  context "#extract_username" do
    let(:http_authorization_value) {"Basic dXNlcjpwYXNzd29yZA==\n"}
    let(:expected_username) {'user'}
    it "should extract the username" do
      matcher = Rack::Throttle::BasicAuthMatcher.new(nil)
      expect(matcher.extract_username(http_authorization_value)).to eq expected_username
    end
  end
end

