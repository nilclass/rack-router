require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe Rack::Router do
  
  it "raises an error if a route is created without specifying an end point" do
    lambda do
      prepare do |r|
        r.map "/hello"
      end
    end.should raise_error(ArgumentError)
  end
  
  it "raises an error if a route is created with an invalid rack application as an end point" do
    lambda do
      prepare do |r|
        r.map "/hello", :to => "HelloApp"
      end
    end.should raise_error(ArgumentError)
  end
  
  it "raises an exception if a single rack router app gets mounted twice" do
    lambda {
      child = router { |c| c.map "/child", :to => ChildApp, :name => :child }
      prepare do |r|
        r.map "/first",  :to => child
        r.map "/second", :to => child
      end
    }.should raise_error
  end
  
end