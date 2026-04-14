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

  test "factory details title switches between active and legacy presentation" do
    quote = quote_requests(:one)
    item = quote.quote_items.first

    item.update!(width_mm: 3830, ceiling_drop_mm: 2410, curtain_price: 440, track_price: 0, track_metres_required: 0)
    assert quote.reload.active_curtain_only_pricing?
    assert_equal "Installation / accessory details (TO LOCAL FACTORY)", quote.factory_details_section_title

    item.update!(track_selected: "M", track_price: 130, track_metres_required: 4)
    assert quote.reload.show_track_details?
    assert_equal "Track details (TO LOCAL FACTORY)", quote.factory_details_section_title
  end

  test "document heading helpers adapt between active and legacy records" do
    quote = quote_requests(:one)
    item = quote.quote_items.first

    item.update!(width_mm: 3830, ceiling_drop_mm: 2410, curtain_price: 440, track_price: 0, track_metres_required: 0)
    quote.reload

    assert_equal "Style", quote.style_heading_label
    assert_equal "Openings (1 / 2)", quote.opening_count_heading_label
    assert_nil quote.track_group_heading
    assert_nil quote.track_length_heading_label
    assert_equal "Opening Code", quote.opening_code_heading_label
    assert_equal "Style\n(\u6b3e\u5f0f)\n\u86c7\u5f62", quote.factory_style_heading_label(multiline: true)

    item.update!(track_selected: "M", track_price: 130, track_metres_required: 4)
    quote.reload

    assert_equal "Style (S Wave / Pinch Pleat)", quote.style_heading_label
    assert_equal "OW (1) or C/O (2)", quote.opening_count_heading_label
    assert_equal "Tracks", quote.track_group_heading
    assert_equal "Length", quote.track_length_heading_label
    assert_equal "OW or C/O", quote.opening_code_heading_label
    assert_equal "Style\n(\u6b3e\u5f0f)\n\u86c7\u5f62/\u97e9\u54f2", quote.factory_style_heading_label(multiline: true)
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
