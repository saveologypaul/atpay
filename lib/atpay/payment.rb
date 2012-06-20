require 'rubygems'
require 'crack'
require 'httparty'
module ATPAY
class Payment
  include HTTParty
  basic_auth ENV['LITLE_USERNAME'], ENV['LITLE_PASSWORD']
  default_timeout 15
  attr_accessor :billing, :order, :user, :card
  attr_accessor :http_response, :success
  attr_accessor :dynamic_tags, :xml
  attr_accessor :username, :password, :host
  def initialize(username, password, host)
    @username = username
    @password = password
    @host = host
  end
  #def initialize(args)
  #  @url = args[:url] || ENV['LITLE_API_URL']
  #  @billing = args[:billing]
  #  @order = args[:order]
  #  @user = args[:user]
  #  @card = args[:card]
  #end

  #def self.send(args)
  #  (litle = self.new(args)).send; litle
  #end

  def send
    fire_payment_request
    handle_payment_response
    successful?
  end

  def successful?
    !!@success
  end

  def handle_payment_response
    @success = false
    result = {}
    begin
      result = Crack::XML.parse(@http_response.body)['soap:Envelope']['soap:Body']['RegularTransactionResponse']['RegularTransactionResult']
      @success = (result['SuccessFlag'] == 'true')
    rescue NoMethodError
    end
    if @success
      @order.litle_confirmation = result['TransactionID']
    else
      @order.errors.add(:base,"Sorry we were unable to process your card")
    end
  end

  def fire_payment_request
    begin
      @xml = render_xml
      puts @xml
      self.class.headers  'Content-Type' => 'text/xml; charset=utf-8',
                          'Content-Length' => @xml.length.to_s,
                          'SOAPAction' => 'http://transactions.atpay.net/webservices/ATPayTxWS/RegularTransaction'
      @http_response = self.class.post(@url, :body => @xml)
      puts @http_response.body
    rescue => e
      puts e
    end
  end

  def affiliate_id
    @order.affiliate_id || 1092
  end

  def free_text
    "Lead=#{@user.id}; OPR=#{@user.id}; AFF=#{affiliate_id}; SKU=#{@billing.sku}; EMAIL=#{@user.email}"
  end

  def render_xml
    @dynamic_tags = dynamic_tags
    template = File.open('./app/views/litle/request.xml.erb', 'r').read
    ERB.new(template).result(binding)
  end

  def credit_card_type
    type = CreditCardValidator::Validator.card_type(@card.number)
    card_types = HashWithIndifferentAccess.new({
      :visa => 'Visa',
      :master_card => 'MasterCard',
      :diners_club => 'Diners',
      :amex => 'AmericanExpress',
      :discover => 'Discover'
    })
    card_types[type] || 'Empty'
  end

  def dynamic_tags
    tags = {
      'Amount' => @billing.amount,
      'BaseAmount' => @billing.base_amount,
      'CreditCardCVV2' => @card.avs,
      'CreditCardExpirationDate' => @card.litle_expiration_date,
      'CreditCardNameOnCard' => @card.name_on_card,
      'CreditCardNumber' => @card.number,
      'CreditCardType' => credit_card_type,
      'CustomerDateTime' => Time.now.iso8601,
      'EndUserBillingAddressPhoneNumber1' => @card.phone,
      'EndUserBillingAddressNumber' => "",
      'EndUserBillingAddressStreet' => "",
      'EndUserBillingAddressCity' => "",
      'EndUserBillingAddressState' => "",
      'EndUserBillingAddressZipPostalCode' => @card.billing_zip,
      'EndUserEmailAddress' => @user.email,
      'EndUserFirstName' => @user.first_name,
      'EndUserIPAddress' => @order.ip_address || '127.0.0.1',
      'EndUserLastName' => @user.last_name,
      'MerchantFreeText' => free_text,
      'AccountID' => @billing.account_id,
      'SubAccountID' => @billing.sub_account_id,
      'ServiceExpiryMethod' => @billing.service_expiry_method,
      'ServiceExpiryMethodAdditionalInfo' => @billing.service_expiry_method_additional_info,
    }
    recurring_tags = {
      true => {
        'RecurringBillingFlag' => true,
        'FirstInstallmentAmount' => @billing.first_installment_amount,
        'InitialPreAuthAmount' =>  @billing.initial_pre_auth_amount,
        'FirstInstallmentInterval' => @billing.first_installment_interval,
        'RecurringAmount' => @billing.recurring_amount,
        'RecurringInstallmentIntervalMethod' => @billing.recurring_installment_interval_method,
        'RecurringInstallmentIntervalMethodAdditionalInfo' => @billing.recurring_installment_interval_method_additional_info,
      },

      false => {
        'RecurringBillingFlag' => false,
        'FirstInstallmentAmount' => 0,
        'InitialPreAuthAmount' => 0,
        'FirstInstallmentInterval' => 0,
        'RecurringAmount' => 0,
        'RecurringInstallmentIntervalMethod' => 'Daily',
      },
    }
    tags.update( recurring_tags[@billing.recurring?] )
  end

end
end
