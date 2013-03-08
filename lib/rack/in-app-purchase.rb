require 'rack'
require 'rack/contrib'

require 'sinatra/base'
require 'sinatra/param'
require 'rack'

require 'sequel'

require 'venice'

module Rack
  class InAppPurchase < Sinatra::Base
    VERSION = '0.0.2'

    use Rack::PostBodyContentTypeParser
    helpers Sinatra::Param

    Sequel.extension :core_extensions, :migration

    autoload :Product, ::File.join(::File.dirname(__FILE__), 'in-app-purchase/models/product')
    autoload :Receipt, ::File.join(::File.dirname(__FILE__), 'in-app-purchase/models/receipt')

    disable :raise_errors, :show_exceptions

    before do
      content_type :json
    end

    get '/products/identifiers' do
      Product.where(is_enabled: true).map(:product_identifier).to_json
    end

    post '/receipts/verify' do
      param :'receipt-data', String, required: true

      status 203

      begin
        receipt = Venice::Receipt.verify!(params[:'receipt-data'])

        Receipt.create({ip_address: request.ip}.merge(receipt.to_h))

        content = settings.content_callback.call(receipt) rescue nil

        {
          status: 0,
          receipt: receipt.to_h,
          content: content
        }.select{|k,v| v}.to_json
      rescue Venice::ReceiptVerificationError => error
        {
          status: Integer(error.message)
        }.to_json
      rescue
        halt 500
      end
    end
  end
end
