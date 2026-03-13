require "test_helper"

class InvoicePdfRendererTest < ActiveSupport::TestCase
  test "renders invoice pdf with key order fields" do
    quote_request = quote_requests(:one)

    pdf = InvoicePdfRenderer.new(quote_request).render

    assert pdf.start_with?("%PDF-1.4")
    assert_includes pdf, OrderDocumentCopy.heading.upcase
    assert_includes pdf, OrderDocumentCopy.subtitle
    assert_includes pdf, OrderDocumentCopy.intro
    assert_includes pdf, OrderDocumentCopy.terms
    assert_includes pdf, OrderDocumentCopy.footer
    assert_includes pdf, quote_request.quote_number
    assert_includes pdf, "Location"
    assert_includes pdf, "Description"
    assert_includes pdf, "TOTAL \\(ex GST\\)"
    assert_includes pdf, "TOTAL \\(inc GST\\)"
    assert_includes pdf, "Bank details"
  end
end
