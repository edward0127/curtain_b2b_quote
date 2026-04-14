require "test_helper"

class InvoicePdfRendererTest < ActiveSupport::TestCase
  test "renders invoice pdf without track column for new active records" do
    quote_request = quote_requests(:one)

    pdf = InvoicePdfRenderer.new(quote_request).render

    assert pdf.start_with?("%PDF-1.4")
    assert_includes pdf, OrderDocumentCopy.heading.upcase
    assert_includes pdf, "Location"
    assert_includes pdf, "Description"
    assert_includes pdf, "Opening"
    assert_includes pdf, "TOTAL \\(ex GST\\)"
    assert_not_includes pdf, "Track"
  end

  test "renders invoice pdf with track column for legacy records" do
    quote_request = quote_requests(:one)
    quote_request.quote_items.first.update!(track_selected: "M", track_price: 130, track_metres_required: 4)

    pdf = InvoicePdfRenderer.new(quote_request).render

    assert_includes pdf, "Track"
  end
end
