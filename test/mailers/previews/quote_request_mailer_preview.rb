# Preview all emails at http://localhost:3000/rails/mailers/quote_request_mailer
class QuoteRequestMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/quote_request_mailer/new_quote_request
  def new_quote_request
    user = User.new(email: "customer@example.com")
    quote = QuoteRequest.new(id: 1001, user: user, width: 240, height: 220, quantity: 4, notes: "Wave pleat", status: :submitted)

    QuoteRequestMailer.new_quote_request(quote)
  end
end
