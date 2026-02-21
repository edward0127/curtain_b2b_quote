class QuotePdfRenderer
  PAGE_HEIGHT = 842
  MARGIN_LEFT = 42
  START_Y = 800
  LINE_HEIGHT = 14
  MAX_LINES = 50

  def initialize(quote_request)
    @quote_request = quote_request
  end

  def render
    content_stream = build_content_stream
    objects = [
      "<< /Type /Catalog /Pages 2 0 R >>",
      "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
      "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 #{PAGE_HEIGHT}] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>",
      "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
      "<< /Length #{content_stream.bytesize} >>\nstream\n#{content_stream}\nendstream"
    ]

    assemble_pdf(objects)
  end

  private

  def build_lines
    lines = []
    lines << @quote_request.quote_template.heading.to_s
    lines << "Quote Number: #{@quote_request.quote_number}"
    lines << "Customer: #{@quote_request.user.email}"
    lines << "Status: #{@quote_request.status.humanize}"
    lines << "Valid Until: #{@quote_request.valid_until}"
    lines << "Reference: #{@quote_request.customer_reference}" if @quote_request.customer_reference.present?
    lines << ""
    lines << "Items"

    @quote_request.quote_items.each_with_index do |item, index|
      line = "#{index + 1}. #{item.product.name} | Qty #{item.quantity} | Unit #{money(item.unit_price)} | Line #{money(item.line_total)}"
      lines << line
      if item.product.per_square_meter?
        lines << "   Size #{item.width} x #{item.height} cm (#{item.area_sqm} sqm)"
      end
    end

    lines << ""
    lines << "Total: #{money(@quote_request.total)}"
    lines << ""
    lines << wrap_line(@quote_request.quote_template.terms.to_s)
    lines << wrap_line(@quote_request.quote_template.footer.to_s)
    lines.flatten.compact.map(&:to_s).reject(&:blank?).first(MAX_LINES)
  end

  def build_content_stream
    y_position = START_Y

    build_lines.map do |line|
      instruction = "BT /F1 11 Tf #{MARGIN_LEFT} #{y_position} Td (#{escape_pdf_text(line)}) Tj ET"
      y_position -= LINE_HEIGHT
      instruction
    end.join("\n")
  end

  def wrap_line(text, max_length: 95)
    text.scan(/.{1,#{max_length}}(?:\s+|$)|\S+/).map(&:strip)
  end

  def money(value)
    format("%s %.2f", @quote_request.currency, value.to_d)
  end

  def escape_pdf_text(value)
    value.to_s.gsub("\\", "\\\\").gsub("(", "\\(").gsub(")", "\\)")
  end

  def assemble_pdf(objects)
    offsets = []
    output = +"%PDF-1.4\n"

    objects.each_with_index do |object, index|
      offsets << output.bytesize
      output << "#{index + 1} 0 obj\n#{object}\nendobj\n"
    end

    xref_offset = output.bytesize
    output << "xref\n0 #{objects.size + 1}\n"
    output << "0000000000 65535 f \n"
    offsets.each do |offset|
      output << format("%010d 00000 n \n", offset)
    end
    output << "trailer\n<< /Size #{objects.size + 1} /Root 1 0 R >>\nstartxref\n#{xref_offset}\n%%EOF"
    output
  end
end
