require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Atpay" do
  describe "Payment" do
    let(:username) { "testusername" }
    let(:password) { "testpassword" }
    let(:host) { "http://testhost.com" }
    let(:card) { 
       {
         :number => '4111111111111111',
         :cvv => '444',
         :expiration_date => '10/2015',
         :name_on_card => 'Jacob Smith'
       } 
    }
    let(:order) {
       {
         :total => '10.00'
       }
    }
    let(:additional_params) {
       {
         :email => 'test@123.com',
         :order_id => '4444444'
       }
    }
    let(:payment_options) {
      {:card => card,
       :order => order
      }
    }
    let(:recurring_payment_options) {
      {:recurring_payment => true,
       :card => card,
       :order => order
      }
    }
    subject { ATPAY::Payment.new username, password, host }
    it "should initialize" do
      subject.username.should == username
      subject.password.should == password
      subject.host.should == host
    end
    it "should accept a payment request" do
      subject.charge payment_options
      subject.recurring_payment.should be_false
    end
    it "should default to standard payment" do
      subject.charge payment_options
      subject.recurring_payment.should be_false
    end
    it "should accept a reccuring payment request" do
      subject.charge recurring_payment_options
      subject.recurring_payment.should be_true
    end
  end
end
