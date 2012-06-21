require 'active_support/core_ext/hash'
require 'rubygems'
require 'crack'
require 'httparty'
require 'erb'
require 'credit_card_validator'

module ATPAY
  class Payment
    include HTTParty
    basic_auth ENV['LITLE_USERNAME'], ENV['LITLE_PASSWORD']
    default_timeout 15
    attr_accessor :username, :password, :host
    #user info
    attr_accessor :first_name
    attr_accessor :last_name
    attr_accessor :email
    attr_accessor :address
    attr_accessor :address2
    attr_accessor :city
    attr_accessor :state
    attr_accessor :zip
    attr_accessor :phone
    attr_accessor :ip_address
    #card info
    attr_accessor :name_on_card
    attr_accessor :number
    attr_accessor :credit_card_type
    attr_accessor :cvv
    attr_accessor :expiration_date
    #charge info
    attr_accessor :amount
    attr_accessor :order_id
    attr_accessor :free_text
    #recurrring info
    attr_accessor :recurring_payment
    attr_accessor :base_amount
    attr_accessor :first_installment_amount
    attr_accessor :initial_pre_auth_amount
    attr_accessor :first_installment_interval
    attr_accessor :recurring_amount
    attr_accessor :recurring_installment_interval_method
    attr_accessor :recurring_installment_interval_method_additional_info
    attr_accessor :account_id
    attr_accessor :sub_account_id
    attr_accessor :service_expiry_method
    attr_accessor :service_expiry_method_additional_info
    #results
    attr_accessor :request
    attr_accessor :response
    attr_accessor :success
    attr_accessor :transaction_id
    #internal
    attr_accessor :error, :org_options, :dynamic_tags, :xml

    def initialize
      @username = ATPAY.username
      @password = ATPAY.password
      @host = ATPAY.host
      @ip_address = '127.0.0.1'
      @error = @first_name = @last_name = @email = @address = @address2 = @city = @state = @zip = @phone = @name_on_card = @number = @credit_card_type = @cvv = @expiration_date = @free_text = @recurring_installment_interval_method_additional_info = @account_id = @sub_account_id = @service_expiry_method = @service_expiry_method_additional_info = @request = @response = @transaction_id = @org_options = @dynamic_tags = @xml = @order_id = ''
      @amount = @base_amount = @first_installment_amount = @initial_pre_auth_amount = @first_installment_interval = @recurring_amount = 0
      @recurring_payment = @success = false
      @recurring_installment_interval_method = 'Daily'
    end

    def charge(options = {})
      @org_options = options

      #user info
      @first_name = options[:first_name] if options[:first_name]
      @last_name = options[:last_name] if options[:last_name]
      @email = options[:email] if options[:email]
      @address = options[:address] if options[:address]
      @address2 = options[:address2] if options[:address2]
      @city = options[:city] if options[:city]
      @state = options[:state] if options[:state]
      @zip = options[:zip] if options[:zip]
      @phone = options[:phone] if options[:phone]
      @ip_address = options[:ip_address] if options[:ip_address]

      #card info
      @name_on_card = options[:name_on_card]
      @number = options[:number]
      @cvv = options[:cvv]
      @expiration_date = options[:expiration_date]
      @credit_card_type = options[:credit_card_type] if options[:credit_card_type]

      #charge info
      @amount = options[:amount] if options[:amount]
      @order_id = options[:order_id] if options[:order_id]
      @free_text = options[:free_text] if options[:free_text]

      #recurring info
      @recurring_payment = options[:recurring_payment] if options[:recurring_payment]
      @base_amount = options[:base_amount] if options[:base_amount]
      @first_installment_amount = options[:first_installment_amount] if options[:first_installment_amount]
      @initial_pre_auth_amount = options[:initial_pre_auth_amount] if options[:initial_pre_auth_amount]
      @first_installment_interval = options[:first_installment_interval] if options[:first_installment_interval]
      @recurring_amount = options[:recurring_amount] if options[:recurring_amount]
      @recurring_installment_interval_method = options[:recurring_installment_interval_method] if options[:recurring_installment_interval_method]
      @recurring_installment_interval_additional_info = options[:recurring_installment_interval_additional_info] if options[:recurring_installment_interval_additional_info]
      @account_id = options[:account_id] if options[:account_id]
      @sub_account_id = options[:sub_account_id] if options[:sub_account_id]
      @service_expiry_method = options[:service_expiry_method] if options[:service_expiry_method]
      @service_expiry_method_additional_info = options[:service_expiry_method_additional_info] if options[:service_expiry_method_additional_info]
      @dynamic_tags = dynamic_tags
      #send_payment_request
      #handle_payment_response
      #successful?
    end

    def credit_card_type
      type = CreditCardValidator::Validator.card_type(@number)
      card_types = HashWithIndifferentAccess.new({
        :visa => 'Visa',
        :master_card => 'MasterCard',
        :diners_club => 'Diners',
        :amex => 'AmericanExpress',
        :discover => 'Discover'
      })
      card_types[type] || 'Empty'
    end

    def send_payment_request
      fire_payment_request
      handle_payment_response
      successful?
    end

    def handle_payment_response
      @success = false
      result = {}
      begin
        result = Crack::XML.parse(@response.body)['soap:Envelope']['soap:Body']['RegularTransactionResponse']['RegularTransactionResult']
        @success = (result['SuccessFlag'] == 'true')
      rescue NoMethodError
      end
      if @success
        @transaction_id = result['TransactionID']
      else
        @error = "Sorry we were unable to process your card"
      end
    end

    def fire_payment_request
      begin
        @xml = render_xml
        puts @xml
        self.class.headers  'Content-Type' => 'text/xml; charset=utf-8',
                            'Content-Length' => @xml.length.to_s,
                            'SOAPAction' => 'http://transactions.atpay.net/webservices/ATPayTxWS/RegularTransaction'
        @response = self.class.post(@url, :body => @xml)
        puts @response.body
      rescue => e
        puts e
      end
    end

    def render_xml
      @dynamic_tags = dynamic_tags
      template = File.open('./lib/atpay/request.xml.erb', 'r').read
      ERB.new(template).result(binding)
    end


    def dynamic_tags
      tags = {
        'Amount' => amount,
        'BaseAmount' => base_amount,
        'CreditCardCVV2' => cvv,
        'CreditCardExpirationDate' => expiration_date,
        'CreditCardNameOnCard' => name_on_card,
        'CreditCardNumber' => number,
        'CreditCardType' => credit_card_type,
        'CustomerDateTime' => Time.now.iso8601,
        'EndUserBillingAddressPhoneNumber1' => phone,
        'EndUserBillingAddressNumber' => address,
        'EndUserBillingAddressStreet' => address2,
        'EndUserBillingAddressCity' => city,
        'EndUserBillingAddressState' => state,
        'EndUserBillingAddressZipPostalCode' => zip,
        'EndUserEmailAddress' => email,
        'EndUserFirstName' => first_name,
        'EndUserIPAddress' => ip_address,
        'EndUserLastName' => last_name,
        'MerchantFreeText' => free_text,
        'AccountID' => account_id,
        'SubAccountID' => sub_account_id,
        'ServiceExpiryMethod' => service_expiry_method,
        'ServiceExpiryMethodAdditionalInfo' => service_expiry_method_additional_info,
      }
      recurring_tags = {
        true => {
          'RecurringBillingFlag' => recurring_payment,
          'FirstInstallmentAmount' => first_installment_amount,
          'InitialPreAuthAmount' =>  initial_pre_auth_amount,
          'FirstInstallmentInterval' => first_installment_interval,
          'RecurringAmount' => recurring_amount,
          'RecurringInstallmentIntervalMethod' => recurring_installment_interval_method,
          'RecurringInstallmentIntervalMethodAdditionalInfo' => recurring_installment_interval_method_additional_info,
        },

        false => {
          'RecurringBillingFlag' => recurring_payment,
          'FirstInstallmentAmount' => 0,
          'InitialPreAuthAmount' => 0,
          'FirstInstallmentInterval' => 0,
          'RecurringAmount' => 0,
          'RecurringInstallmentIntervalMethod' => 'Daily',
        },
      }
      tags.update( recurring_tags[recurring_payment] )
    end
  end
end
