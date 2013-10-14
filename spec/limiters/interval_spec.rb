require File.join(File.dirname(__FILE__), '..', 'spec_helper')


describe Rack::Throttle::Interval do
  include Rack::Test::Methods
  
  def app
    @target_app ||= example_target_app
    @app ||= Rack::Throttle::Interval.new(@target_app, :min => 0.1)
  end

  it "should allow the request if the source has not been seen" do
    get "/foo"
    last_response.body.should show_allowed_response
  end
  
  it "should allow the request if the source has not been seen in the current interval" do
    Timecop.freeze do
      get "/foo"
      Timecop.freeze(1) do # Timecop.freeze won't do subsecond resolution
        get "/foo"
      end
    end
    last_response.body.should show_allowed_response
  end

  it "should allow the request if a different source has been seen in the current interval" do
    Timecop.freeze do
      get "/foo", {}, "REMOTE_ADDR" => "127.0.0.2"
      get "/foo", {}, "REMOTE_ADDR" => "127.0.0.3"
    end
    last_response.body.should show_allowed_response
  end
  
  it "should not allow the request if the source has been seen inside the current interval" do
    Timecop.freeze do
      2.times { get "/foo" }
    end
    last_response.body.should show_throttled_response
  end
  
  it "should gracefully allow the request if the cache bombs on getting" do
    app.should_receive(:cache_get).and_raise(StandardError)
    get "/foo"
    last_response.body.should show_allowed_response
  end
  
  it "should gracefully allow the request if the cache bombs on setting" do
    app.should_receive(:cache_set).and_raise(StandardError)
    get "/foo"
    last_response.body.should show_allowed_response
  end
end
