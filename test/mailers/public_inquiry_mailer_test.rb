require "test_helper"

class PublicInquiryMailerTest < ActionMailer::TestCase
  test "new_public_inquiry" do
    app_setting = app_settings(:default)
    form = PublicContactForm.new(
      first_name: "Alex",
      last_name: "Chen",
      email: "alex@example.com",
      company: "Acme Builders",
      message: "Please share pricing for an upcoming townhouse project.",
      subscribe_updates: true
    )

    mail = PublicInquiryMailer.new_public_inquiry(form)

    assert_equal "New Get In Touch Submission - Acme Builders", mail.subject
    assert_equal [ app_setting.quote_receiver_email ], mail.to
    assert_equal [ "no-reply@example.com" ], mail.from
    assert_match "Alex Chen", mail.body.encoded
    assert_match "Acme Builders", mail.body.encoded
    assert_equal app_setting.mailgun_smtp_address, mail.delivery_method.settings[:address]
  end
end
