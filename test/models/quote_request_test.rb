require "test_helper"

class QuoteRequestTest < ActiveSupport::TestCase
  test "status enum includes new order lifecycle values" do
    assert_equal 7, QuoteRequest.statuses.fetch("order_processing")
    assert_equal 8, QuoteRequest.statuses.fetch("ready_for_pick_up")
    assert_equal 9, QuoteRequest.statuses.fetch("completed")
    assert_equal 10, QuoteRequest.statuses.fetch("cancelled")
  end

  test "status label mapping handles known and unknown statuses" do
    assert_equal "Ready For Pick Up", QuoteRequest.status_label_for(:ready_for_pick_up)
    assert_equal "Custom status", QuoteRequest.status_label_for("custom_status")
    assert_equal "Unknown", QuoteRequest.status_label_for(nil)
  end

  test "b2c mode requires company name" do
    quote = build_quote(customer_mode: :b2c, company_name: nil)

    assert_not quote.valid?
    assert_includes quote.errors[:company_name], "can't be blank"
  end

  test "b2b mode does not require company name" do
    quote = build_quote(customer_mode: :b2b, company_name: nil)

    assert quote.valid?
  end

  test "order status transitions stamp v2 timestamps" do
    quote = quote_requests(:one)

    quote.transition_to!(:order_processing)
    assert_equal "order_processing", quote.status
    assert_not_nil quote.submitted_at

    quote.transition_to!(:ready_for_pick_up)
    assert_equal "ready_for_pick_up", quote.status
    assert_not_nil quote.ready_for_pick_up_at

    quote.transition_to!(:completed)
    assert_equal "completed", quote.status
    assert_not_nil quote.completed_at
  end

  test "approved status no longer transitions to converted_to_job" do
    quote = build_quote(customer_mode: :b2b, company_name: nil, status: :approved)

    assert_not quote.can_transition_to?(:converted_to_job)
    assert quote.can_transition_to?(:order_processing)
  end

  private

  def build_quote(customer_mode:, company_name:, status: :submitted)
    quote = QuoteRequest.new(
      user: users(:customer),
      currency: "AUD",
      notes: "Test",
      customer_mode: customer_mode,
      company_name: company_name,
      status: status
    )

    quote.quote_items.build(
      product: products(:sheer_panel),
      line_position: 1,
      width: 200,
      height: 250,
      quantity: 1
    )

    quote
  end
end
