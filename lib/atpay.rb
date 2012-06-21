require 'atpay/payment'
module ATPAY
  class << self
   attr_accessor :username
   attr_accessor :password
   attr_accessor :host
  end
  def self.configure(&block)
    yield(self)
  end
end
