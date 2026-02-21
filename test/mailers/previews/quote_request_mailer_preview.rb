# Preview all emails at http://localhost:3000/rails/mailers/quote_request_mailer
class QuoteRequestMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/quote_request_mailer/new_quote_request
  def new_quote_request
    quote = QuoteRequest.includes(:user, :quote_template, quote_items: :product).first
    return QuoteRequestMailer.new_quote_request(quote) if quote.present?

    user = User.first || User.new(email: "preview@example.com")
    template = QuoteTemplate.default_template || QuoteTemplate.new(name: "preview", heading: "Preview Quote")
    product = Product.first || Product.new(name: "Preview Product", base_price: 50, pricing_mode: :per_square_meter)
    fallback_quote = QuoteRequest.new(
      id: 1001,
      user: user,
      quote_template: template,
      quote_number: "Q-20260221-10001",
      customer_reference: "PREVIEW-REF",
      currency: "AUD",
      valid_until: 14.days.from_now.to_date,
      width: 100,
      height: 200,
      quantity: 1,
      subtotal: 100,
      total: 100,
      notes: "Preview quote",
      status: :submitted
    )
    fallback_quote.quote_items.build(
      product: product,
      line_position: 1,
      width: 100,
      height: 200,
      quantity: 1,
      area_sqm: 2.0,
      unit_price: 50,
      line_total: 100
    )

    quote = fallback_quote
    QuoteRequestMailer.new_quote_request(quote)
  end
end
