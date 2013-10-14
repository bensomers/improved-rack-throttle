require File.join(File.dirname(__FILE__), '..', 'spec_helper')


describe Rack::Throttle::Interval do
  include Rack::Test::Methods
  
  def app
    @target_app ||= example_target_app
    @app ||= Rack::Throttle::Interval.new(@target_app, global: true, :min => 0.1)
  end

  context "global" do
    before(:each) do
      Rack::MockRequest.any_instance.stub(:ip).and_return("127.0.0.2", "127.0.0.3")
    end

    it "should not allow the request if any source has been seen inside the current interval" do
      Timecop.freeze do
        get "/foo"
        get "/foo"
      end

      last_response.body.should show_throttled_response
    end
  end
end
