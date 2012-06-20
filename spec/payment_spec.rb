require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Atpay" do
  describe "Payment" do
    let(:username) { "testusername" }
    let(:password) { "testpassword" }
    let(:host) { "http://testhost.com" }
    let(:card) { 
       {
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
       :order => order,
       :number => '4111111111111111',
       :cvv => '444',
       :expiration_date => '10/2015',
       :name_on_card => 'Jacob Smith'
      }
    }
    let(:recurring_payment_options) {
      {:recurring_payment => true,
       :card => card,
       :order => order
      }
    }
    let(:free_text){
      "Lead=3333; OPR=4000; AFF=1092; SKU=55555; EMAIL=test@123.com"
    }
    subject { ATPAY::Payment.new username, password, host }
    it "should initialize" do
      subject.username.should == username
      subject.password.should == password
      subject.host.should == host
      subject.first_name.should == ''
      subject.last_name.should == ''
      subject.email.should == ''
      subject.address.should == ''
      subject.address2.should == ''
      subject.city.should == ''
      subject.state.should == ''
      subject.zip.should == ''
      subject.phone.should == ''
      subject.ip_address.should == '127.0.0.1'
      subject.name_on_card.should == ''
      subject.number.should == ''
      subject.credit_card_type.should == ''
      subject.cvv.should == ''
      subject.expiration_date.should == ''
      subject.amount.should == 0
      subject.free_text.should == ''
      subject.recurring_payment.should be_false
      subject.base_amount.should == 0
      subject.first_installment_amount.should == 0
      subject.initial_pre_auth_amount.should == 0
      subject.first_installment_interval.should == 0
      subject.recurring_amount.should == 0
      subject.recurring_installment_interval_method.should == 'Daily'
      subject.recurring_installment_interval_additional_info.should == ''
      subject.account_id.should == ''
      subject.sub_account_id.should == ''
      subject.service_expiry_method.should == ''
      subject.service_expiry_method_additional_info.should == ''
      subject.request.should == ''
      subject.response.should == ''
      subject.success.should be_false
      subject.transaction_id.should == ''
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
