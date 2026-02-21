require "test_helper"

class QuoteRequestMailerTest < ActionMailer::TestCase
  test "new_quote_request" do
    quote_request = quote_requests(:one)
    app_setting = app_settings(:default)

    mail = QuoteRequestMailer.new_quote_request(quote_request)
    assert_equal "New Curtain Quote Request ##{quote_request.id}", mail.subject
    assert_equal [ app_setting.quote_receiver_email ], mail.to
    assert_equal [ "no-reply@example.com" ], mail.from
    assert_match quote_request.user.email, mail.body.encoded
    assert_match quote_request.quote_number, mail.body.encoded
    assert_equal app_setting.mailgun_smtp_address, mail.delivery_method.settings[:address]
  end
end
