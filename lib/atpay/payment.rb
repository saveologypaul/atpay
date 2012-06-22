require 'active_support/core_ext/hash'
require 'rubygems'
require 'crack'
require 'httparty'
require 'erb'
require 'credit_card_validator'

module ATPAY
  class Payment
    include HTTParty
    attr_accessor :username, :password, :host
    default_timeout 15
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
    attr_accessor :response_code, :errors, :error, :atpay_error, :error_id, :org_options, :dynamic_tags, :xml

    def initialize
      @username = ATPAY.username
      @password = ATPAY.password
      @host = ATPAY.host
      @ip_address = '127.0.0.1'
      @error = @first_name = @last_name = @email = @address = @address2 = @city = @state = @zip = @phone = @name_on_card = @number = @credit_card_type = @cvv = @expiration_date = @free_text = @recurring_installment_interval_method_additional_info = @account_id = @sub_account_id = @service_expiry_method = @service_expiry_method_additional_info = @request = @response = @transaction_id = @org_options = @dynamic_tags = @xml = @order_id = ''
      @amount = @base_amount = @first_installment_amount = @initial_pre_auth_amount = @first_installment_interval = @recurring_amount = 0
      @recurring_payment = @success = false
      @recurring_installment_interval_method = 'Daily'
      errors
    end

    def charge(options = {})
      self.class.basic_auth(ATPAY.username, ATPAY.password)
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
      send_payment_request
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
      success
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
        return true
      else
        if @response.body =~ /Unauthorized: Access is denied due to invalid credentials/
          @error = 'Access is denied due to invalid credentials'
        else
          @error_id = @response.parsed_response["Envelope"]["Body"]["RegularTransactionResponse"]["RegularTransactionResult"]["ErrorID"]
          @error = "Sorry we were unable to process your card"
          @atpay_error = @errors[@error_id.to_i] if @errors[@error_id.to_i].present?
        end
        return false
      end
    end
    def soap_action
      ['http://transactions.atpay.net','/webservices/ATPayTxWS/RegularTransaction'].join('')
    end
    def url
      [@host,'/TxWS/ATPayTxWS.asmx'].join('')
    end
    def fire_payment_request
      begin
        @request = @xml = render_xml
        #puts @xml
        self.class.headers  'Content-Type' => 'text/xml; charset=utf-8',
                            'Content-Length' => @xml.length.to_s,
                            'SOAPAction' => soap_action
        @response = self.class.post(url, :body => @xml)
        #puts @response.body
      rescue => e
        #puts e
      end
    end

    def render_xml
      @dynamic_tags = dynamic_tags
      template = File.open(File.dirname(__FILE__)+'/request.xml.erb', 'r').read
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
        'EndUserBillingAddressNumber' => '',
        'EndUserBillingAddressStreet' => address + ' ' +address2,
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

    def errors
      @errors = {
      0 => "OK",
      10001 => "Blocked - issuer response",
      10002 => "Stolen -  issuer response",
      10003 => "Contact credit card company - issuer response",
      10004 => "General refusal -  issuer response",
      10005 => "Forged - issuer response",
      10006 => "CVV2 value invalid",
      10007 => "Connection to clearing interface unsuccessful",
      10008 => "Error in request string to clearing interface",
      10009 => "Invalid card",
      10010 => "Request contradicts clearing interface configuration",
      10011 => "Card expired",
      10012 => "Error in feature that is not supposed to be in use",
      10013 => "Incorrect secret code",
      10014 => "Incorrect secret code - last try",
      10016 => "Previous transaction cannot be cancelled (credit transaction or card number not identical)",
      10017 => "Duplicate Transaction",
      10018 => "Clearing interface application error",
      10019 => "Timeout to clearing interface",
      10020 => "System error",
      10021 => "Cancellation transaction:  Parent transaction was declined or not found",
      10022 => "Cancellation transaction: transaction already processed through the acquirer",
      10023 => "Cancellation transaction: transaction found but already cancelled",
      10024 => "No authorization number found for this transaction",
      10025 => "More than 4 days passed since charge transaction",
      10029 => "Transaction type not allowed for this type of card",
      10030 => "Error in request string",
      10040 => "Deposit Trx not yet settled, trx cannot be credited",
      10070 => "ECI or CAVV incorrect",
      10100 => "Original transaction not found by MID",
      10200 => "No Sufficient Funds",
      10301 => "Amex - Approved (Express Rewards Program)",
      10302 => "Bad Terminal ID",
      10303 => "Card Network Error",
      10304 => "Deny - Account Canceled",
      10305 => "Deny - New card issued",
      10306 => "Exceeds withdrawal limit",
      10307 => "Honor with ID",
      10308 => "Insufficient funds",
      10309 => "Invalid ABA",
      10310 => "Invalid Address",
      10311 => "Invalid amount",
      10312 => "Invalid AVS",
      10313 => "Invalid Card Format",
      10314 => "Invalid Card type",
      10315 => "Invalid DDA",
      10316 => "Invalid Entry Type",
      10317 => "Invalid Merchant ID",
      10318 => "Invalid messge format",
      10319 => "Invalid Password",
      10320 => "Invalid TID",
      10321 => "Invalid Transaction Type",
      10322 => "Invalid ZIP and Address",
      10323 => "Invalid zipcode",
      10324 => "Master Merchant not found",
      10325 => "Merchant ID error",
      10326 => "Partial Approval",
      10327 => "Record Not Found",
      10328 => "Re-enter transaction",
      10329 => "Refund denied",
      10330 => "Suspected Fraud",
      10331 => "System error SD",
      10332 => "Transaction cannot be completed; violation of law.",
      10333 => "Transaction not allowed at terminal",
      10334 => "Transaction not permitted to cardholder",
      10335 => "VIP Approval",
      10336 => "ACH Negative file",
      10337 => "Auth cancelled or revoked",
      10338 => "Problem with original Authorization",
      10340 => "Failed - International transaction",
      10350 => "Invalid Data - General",
      10351 => "Invalid or incorrect account data",
      10352 => "Invalid or incorrect bank data",
      10353 => "Invalid or incorrect check data",
      10354 => "Invalid or incorrect user data",
      10360 => "FX Error",
      10400 => "Cardholder Details Field invalid",
      10401 => "Cardholder Shipping Details Field invalid",
      10402 => "Merchant Details Field invalid",
      10403 => "Amount field invalid",
      10404 => "Transaction field invalid",
      10405 => "Item details field invalid",
      11001 => "SVS Payee Billing Account does not exist in the database.",
      11002 => "SVS Payee Billing Account does not correspond the currency.",
      11003 => "SVS Payer Billing Account does not exist in the database.",
      11004 => "SVS Payer Billing Account does not correspond the currency.",
      11005 => "Acquirer Billing Account does not exist in the database.",
      11006 => "Aquirer Billing Account does not correspond the currency.",
      11007 => "Not enough money for the withdrawal operation. The account balance is less than transaction amount.",
      11008 => "Billing Account is locked for withdrawal operations.",
      11009 => "SVS Payee Billing Account is suspended.",
      11010 => "SVS Payer Billing Account is suspended.",
      11011 => "Acquirer Billing Account is suspended.",
      11015 => "Name on account does not equal the customer full name.",
      11016 => "Merchant External Service execution failed.",
      11021 => "Merchant did not process the transaction and returned response 'Error'.",
      11022 => "The system does not support this currency",
      11023 => "Payee billing account is not a customer account",
      11024 => "Transactions are not allowed between TEST and LIVE accounts.",
      11026 => "Billing Account belongs to the user from country forbidden for payment/payout",
      11027 => "Payee and Payer skins are different",
      11029 => "Billing Account is locked for submit operations.",
      11030 => "This option is currently not available.",
      11031 => "Customer account is currently locked because of velocity check.",
      11100 => "ACH Direct service failed",
      11101 => "ACH Direct did not process the transaction and returned 'Error'",
      11102 => "IDVerify service failed",
      11103 => "IDVerify did not process the transaction and returned 'Error'",
      11104 => "ACH processing service returned fatal error code.",
      11105 => "ACH processing service returned a formatting error.",
      11106 => "Transaction is rejected by ACH processing service.",
      11107 => "Credit Card processing service is unavailable",
      11108 => "Credit Card processing service did not process the transaction and returned 'Error'",
      11109 => "Rejected by Credit Card External Service",
      11110 => "Credit Card processing service is unavailable",
      11111 => "Credit Card processing service did not process the transaction and returned 'Error'",
      11112 => "Rejected by Credit Card External Service",
      11113 => "EFT processing service failed",
      11114 => "EFT processing service did not process the transaction and returned 'Error'",
      11115 => "Transaction is rejected by EFT/PAD processing service.",
      11116 => "Enterpayment service failed",
      11117 => "Enterpayment did not process the transaction and returned 'Error'",
      11118 => "Transaction is rejected by CC processing service.",
      11119 => "Transaction is pending. Please check status of the transaction later.",
      11120 => "BlueWire processing service is unavailable",
      11121 => "BlueWire processing service did not process the transaction and returned 'Error'",
      11122 => "Rejected by BlueWire External Service",
      11123 => "Transaction is rejected by CC processing service.",
      11124 => "DataCash processing service is unavailable",
      11125 => "DataCash processing service did not process the transaction and returned 'Error'",
      11126 => "Rejected by DataCash External Service",
      11127 => "Median processing service is unavailable",
      11128 => "Median processing service did not process the transaction and returned 'Error'",
      11129 => "Rejected by Median External Service",
      11131 => "JetPay service failed",
      11132 => "JetPay did not process the transaction and returned 'Error'",
      11133 => "Transaction is rejected by JetPay processing service",
      11134 => "PaymenTech service failed",
      11135 => "Transaction is rejected by PaymenTech processing service",
      11136 => "PaymenTech did not process the transaction and returned 'Error'",
      11137 => "ConnectNpay service failed",
      11138 => "Transaction is rejected by ConnectNPay processing service",
      11139 => "ConnectNPay did not process the transaction and returned 'Error'",
      11140 => "MES service failed",
      11141 => "Transaction is rejected by MES processing service",
      11142 => "MES did not process the transaction and returned 'Error'",
      11197 => "Transaction Timeout",
      11198 => "Old Processor System Error",
      11199 => "System Error of Acquirer/Processor",
      20001 => "Customer could not be recognized",
      20002 => "Not permitted transaction amount",
      20003 => "Unauthorized user request",
      20006 => "The data of request does not match any service plan",
      20008 => "Requested service plan not allowed",
      20013 => "Illegal transaction packet parameter value",
      20014 => "Credit card is expired or expiration date is invalid",
      20015 => "Negative DB",
      20022 => "DB failure when loading offline transaction parameters",
      20051 => "CVV2 contains non digit chars",
      20052 => "CCType and CCNumber do not match",
      20066 => "Transaction type not allowed for account",
      20100 => "Transaction already cancelled",
      20101 => "Submit Instruction Type does not match Parent Instruction Type",
      20102 => "Expiration date for submit cancel expired",
      20103 => "Transaction already deposited",
      20104 => "Expiration date for submit debit expired",
      20105 => "Cannot run submit credit for non debit original transaction",
      20106 => "Transaction already credited",
      20107 => "Expiration date for submit credit expired",
      20108 => "Query Transaction can not be deferred",
      20109 => "The amount of submit transaction is not equal to the amount of the Parent Trx",
      20110 => "The submit Operation Type does not match the Operation Type of the Parent Trx",
      20111 => "Cannot credit chargeback or retrieval transaction",
      20112 => "Wrong credit card expiration date.",
      20113 => "Total sum of refunds exceed deposit amount",
      20153 => "Transaction already revoked",
      20154 => "Transaction has a final status and can not be updated.",
      20199 => "Authorization Transaction Already collected for capturing process",
      20200 => "Transaction rejected by clearing system",
      20300 => "Transaction rejected by ThreeDSecure",
      20400 => "Transaction declined",
      20500 => "FDS external service execution failed",
      20700 => "Transaction rejected by FDS when FDS response was not allowed",
      21111 => "Old gateway error code",
      25001 => "Transaction failed to load and validate parent transaction information",
      25002 => "QueryByCustTxID result: Original transaction not found",
      30001 => "Chargeback already charged back",
      30002 => "Retrieval already retrieved",
      30003 => "Second CHB in file.",
      30004 => "Amount of chargeback or retrieval is different more than 20% from original deposit amount.",
      30005 => "Parent Transaction Of CHB Not Found",
      30006 => "Currency mismatch of CHB.",
      30007 => "Deposit already received chargeback, credit is not allowed",
      444444 => "An unknown error was received from the processor",
      50001 => "Transaction deleted by the operator ion the Operator Site",
      50002 => "Transaction rejected by the operator in the Operator Site",
      60001 => "Customer originated transaction ID must be unique",
      60002 => "Transaction cancelled due to time out",
      60003 => "Transaction is pending. Try query transaction status later",
      60004 => "Transaction not found",
      60005 => "Country code is wrong or unknown",
      70001 => "Insufficient  or Uncollected Funds",
      70002 => "Invalid or closed account",
      70003 => "No authorization from account holder for action",
      70004 => "Account holder deceased",
      70005 => "Action not permitted on this account",
      70006 => "Account on Hold",
      70050 => "Invalid company data",
      70100 => "Prenote Not Received",
      70101 => "Returned Per ODFI",
      70102 => "Check Safekeeping Return",
      70103 => "Account with branch of another financial institution",
      70104 => "RDFI Does not Participate",
      70105 => "ODFI Permits Late Return",
      70106 => "RDFI Does not permit transaction",
      70107 => "Return issue",
      70108 => "Currency or Cross border issue",
      70109 => "Stop payment on item",
      70110 => "Item and ACH entry presented for payment",
      70111 => "Issue with source documents",
      70112 => "ODFI does not participate or has limited participation",
      70200 => "Duplicate Entry",
      70201 => "Invalid or incomplete transaction data",
      70202 => "Invalid or incomplete transaction data",
      70203 => "Transaction has expired",
      70204 => "Invalid Password",
      70500 => "PP: Account is restricted / Refund not allowed",
      70501 => "Transaction refused because of an invalid argument. See additional error messages for details",
      70502 => "PP: Invalid action for re-authorization transaction",
      70503 => "PP: Order already voided or expired",
      70504 => "Maximum number of authorization allowed for the order is reached.",
      70505 => "The authorization is being processed.",
      70506 => "One or more payment requests failed. Check individual payment responses for more information.",
      88888 => "SOAP request parameter or values are not correct",
      99999 => "System Error"
    }
  end
  end
end
