require "test_helper"

class FactorySheetPdfRendererTest < ActiveSupport::TestCase
  test "renders new active factory sheet pdf without track-specific section title" do
    quote_request = quote_requests(:one)

    pdf = FactorySheetPdfRenderer.new(quote_request).render

    assert pdf.start_with?("%PDF-1.4")
    assert_includes pdf, "ORDER FORM 2026"
    assert_includes pdf, "Fabric details \\(TO GZ FACTORY\\)"
    assert_includes pdf, "Installation / accessory details \\(TO LOCAL FACTORY\\)"
    assert_not_includes pdf, "Track details \\(TO LOCAL FACTORY\\)"
    assert_includes pdf, quote_request.quote_number
  end

  test "renders legacy factory sheet pdf with track-specific section title" do
    quote_request = quote_requests(:one)
    quote_request.quote_items.first.update!(track_selected: "M", track_price: 130, track_metres_required: 4)

    pdf = FactorySheetPdfRenderer.new(quote_request).render

    assert_includes pdf, "Track details \\(TO LOCAL FACTORY\\)"
  end
end
