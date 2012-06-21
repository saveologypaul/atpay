require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
describe ATPAY do
  it "should respond to configure" do
    subject.respond_to?(:configure).should be
  end

  context "should yeild the contents of block with self as the argument" do
    before do
      ATPAY.configure do |config|
        config.username = 'username'
        config.password = 'password'
        config.host = 'http://test.com'
      end
    end
    it "should be able to set attributes" do
      subject.username.should == 'username'
      subject.password.should == 'password'
      subject.host.should == 'http://test.com'
    end
  end
end
