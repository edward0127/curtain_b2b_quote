require "test_helper"

class FactorySheetPdfRendererTest < ActiveSupport::TestCase
  test "renders factory sheet pdf with key fields" do
    quote_request = quote_requests(:one)

    pdf = FactorySheetPdfRenderer.new(quote_request).render

    assert pdf.start_with?("%PDF-1.4")
    assert_includes pdf, "ORDER FORM 2026"
    assert_includes pdf, "Fabric details \\(TO GZ FACTORY\\)"
    assert_includes pdf, "Track details \\(TO LOCAL FACTORY\\)"
    assert_includes pdf, "STSong-Light"
    assert_includes pdf, "UniGB-UCS2-H"
    assert_includes pdf, "/FontDescriptor"
    assert_includes pdf, "/FontBBox"
    assert_includes pdf, quote_request.quote_number
  end
end
