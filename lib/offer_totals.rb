class OfferTotals
  # Given an Order and amount of offer, it calculates tax, shipping based on offer amount
  delegate :tax_total_cents, to: :tax_data
  delegate :should_remit_sales_tax, to: :tax_data
  delegate :shipping_total_cents, to: :order_helper

  def initialize(order, offer_amount = nil)
    @offer_amount = offer_amount
    @order = order
  end

  private

  def artwork_location
    artwork_id = @order.line_items.first.artwork_id # this is with assumption of Offer order only having one lineItem
    artwork = order_helper.artworks[artwork_id]
    @artwork_location ||= Address.new(artwork[:location])
  end

  def tax_data
    @tax_data ||= begin
      service = Tax::CalculatorService.new(
        @offer_amount,
        @offer_amount / @order.line_items.first.quantity,
        @order.line_items.first.quantity,
        @order.fulfillment_type,
        @order.shipping_address,
        order_helper.shipping_total_cents,
        artwork_location,
        order_helper.seller_locations
      )
      sales_tax = order_helper.partner[:artsy_collects_sales_tax] ? service.sales_tax : 0
      OpenStruct.new(tax_total_cents: sales_tax, should_remit_sales_tax: service.artsy_should_remit_taxes?)
    end
  rescue Errors::ValidationError => e
    raise e unless e.code == :no_taxable_addresses

    # If there are no taxable addresses then we set the sales tax to 0.
    OpenStruct.new(tax_total_cents: 0, should_remit_sales_tax: false)
  end

  def order_helper
    @order_helper ||= OrderHelper.new(@order)
  end
end