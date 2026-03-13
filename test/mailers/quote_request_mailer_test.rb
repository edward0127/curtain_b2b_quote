require "test_helper"

class QuoteRequestMailerTest < ActionMailer::TestCase
  test "customer_order_invoice" do
    quote_request = quote_requests(:one)
    quote_request.update!(customer_email: "buyer@example.com", status: :order_processing)

    mail = QuoteRequestMailer.customer_order_invoice(quote_request)
    assert_equal "Invoice / Order #{quote_request.quote_number}", mail.subject
    assert_equal [ "buyer@example.com" ], mail.to
    assert_match OrderDocumentCopy.heading, mail.body.encoded
    assert_match OrderDocumentCopy.subtitle, mail.body.encoded
    assert_match OrderDocumentCopy.intro, mail.body.encoded
    assert_match OrderDocumentCopy.terms, mail.body.encoded
    assert_match OrderDocumentCopy.footer, mail.body.encoded
    assert_match "Location", mail.body.encoded
    assert_match "TOTAL (ex GST)", mail.body.encoded
    assert_match "TOTAL (inc GST)", mail.body.encoded
    assert_match "Bank details", mail.body.encoded
    assert_match AppSetting.current.bank_account_name, mail.body.encoded
    assert_match AppSetting.current.bank_bsb, mail.body.encoded
  end

  test "internal_order_notification" do
    quote_request = quote_requests(:one)
    app_setting = app_settings(:default)
    quote_request.update!(customer_email: "buyer@example.com", status: :order_processing)

    mail = QuoteRequestMailer.internal_order_notification(quote_request)
    assert_equal "New Order Submitted #{quote_request.quote_number}", mail.subject
    assert_equal [ app_setting.quote_receiver_email ], mail.to
    assert_match "buyer@example.com", mail.body.encoded
  end

  test "ready_for_pick_up_notification" do
    quote_request = quote_requests(:one)
    quote_request.update!(customer_email: "pickup@example.com", status: :ready_for_pick_up, pickup_method: :pickup)

    mail = QuoteRequestMailer.ready_for_pick_up_notification(quote_request)
    assert_equal "Order Ready for Pick Up #{quote_request.quote_number}", mail.subject
    assert_equal [ "pickup@example.com" ], mail.to
    assert_match AppSetting.current.pickup_address_default, mail.body.encoded
    assert_match AppSetting.current.delivery_note_default, mail.body.encoded
  end
end
