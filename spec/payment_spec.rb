require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Atpay" do
  describe "Payment" do
    let(:username) { "testusername" }
    let(:password) { "testpassword" }
    let(:host) { "http://testhost.com" }
    subject { ATPAY::Payment.new username, password, host }
    it "should initialize" do
      subject.username.should == username
      subject.password.should == password
      subject.host.should == host
    end
  end
end
