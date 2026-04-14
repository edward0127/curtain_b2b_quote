class InvoicePdfRenderer
  PAGE_WIDTH = 595
  PAGE_HEIGHT = 842
  MARGIN = 36
  CONTENT_WIDTH = PAGE_WIDTH - (MARGIN * 2)
  MAX_ROWS = 18

  COLORS = {
    ink: [0.071, 0.204, 0.278],
    muted: [0.302, 0.396, 0.459],
    line: [0.78, 0.84, 0.89],
    panel: [0.965, 0.976, 0.988],
    heading: [0.91, 0.94, 0.97],
    white: [1.0, 1.0, 1.0]
  }.freeze

  def initialize(quote_request)
    @quote_request = quote_request
    @quotation = Orders::QuotationPresenter.new(quote_request)
    @commands = []
  end

  def render
    draw_document
    content_stream = @commands.join("\n")

    objects = [
      "<< /Type /Catalog /Pages 2 0 R >>",
      "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
      "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 #{PAGE_WIDTH} #{PAGE_HEIGHT}] /Resources << /Font << /F1 4 0 R /F2 5 0 R >> >> /Contents 6 0 R >>",
      "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
      "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>",
      "<< /Length #{content_stream.bytesize} >>\nstream\n#{content_stream}\nendstream"
    ]

    assemble_pdf(objects)
  end

  private

  def draw_document
    y = PAGE_HEIGHT - 40
    y = draw_header_block(y)
    y -= 12
    y = draw_customer_block(y)
    y -= 12
    y = draw_items_table(y)
    y -= 12
    y = draw_totals_block(y)
    y -= 14
    draw_bank_details_block(y)
  end

  def draw_header_block(top_y)
    block_height = 88
    bottom_y = top_y - block_height

    fill_rect(MARGIN, bottom_y, CONTENT_WIDTH, block_height, COLORS[:panel])
    stroke_rect(MARGIN, bottom_y, CONTENT_WIDTH, block_height, COLORS[:line])

    add_text(MARGIN + 12, top_y - 20, OrderDocumentCopy.heading.upcase, size: 17, bold: true)
    add_text(MARGIN + 12, top_y - 38, OrderDocumentCopy.subtitle, size: 11, bold: true, color: COLORS[:muted])
    add_text(MARGIN + 12, top_y - 54, truncate(OrderDocumentCopy.intro, 76), size: 8, color: COLORS[:muted])

    right_x = MARGIN + CONTENT_WIDTH - 200
    add_text(right_x, top_y - 20, "Order No:", size: 9, bold: true, color: COLORS[:muted])
    add_text(right_x + 58, top_y - 20, quotation.order_number, size: 10, bold: true)
    add_text(right_x, top_y - 36, "Date:", size: 9, bold: true, color: COLORS[:muted])
    add_text(right_x + 58, top_y - 36, safe_date(quotation.order_date), size: 9)

    bottom_y
  end

  def draw_customer_block(top_y)
    rows = [
      [ "Customer", quotation.customer_name ],
      [ "Company", quotation.company_name ],
      [ "Email / Phone", customer_contact_line ],
      [ "Delivery address", quotation.delivery_address ],
      [ "Pickup / Delivery", quotation.pickup_method ]
    ].reject { |_, value| value.blank? }

    row_height = 14
    block_height = 14 + (rows.size * row_height)
    bottom_y = top_y - block_height

    fill_rect(MARGIN, bottom_y, CONTENT_WIDTH, block_height, COLORS[:white])
    stroke_rect(MARGIN, bottom_y, CONTENT_WIDTH, block_height, COLORS[:line])

    y = top_y - 16
    rows.each do |label, value|
      add_text(MARGIN + 10, y, "#{label}:", size: 9, bold: true, color: COLORS[:muted])
      add_text(MARGIN + 110, y, truncate(value, 82), size: 9)
      y -= row_height
    end

    bottom_y
  end

  def draw_items_table(top_y)
    columns = if quotation.show_track_details?
      [
        { key: :location, label: "Location", width: 78 },
        { key: :description, label: "Description", width: 220 },
        { key: :opening, label: "Opening", width: 66 },
        { key: :track, label: "Track", width: 44 },
        { key: :total, label: "Total (ex GST)", width: 115 }
      ]
    else
      [
        { key: :location, label: "Location", width: 78 },
        { key: :description, label: "Description", width: 264 },
        { key: :opening, label: "Opening", width: 66 },
        { key: :total, label: "Total (ex GST)", width: 115 }
      ]
    end

    header_height = 22
    row_height = 18
    visible_rows = quotation.rows.first(MAX_ROWS)
    has_omitted = quotation.rows.size > MAX_ROWS
    table_rows = visible_rows.size + (has_omitted ? 1 : 0)
    table_height = header_height + (table_rows * row_height)
    bottom_y = top_y - table_height

    fill_rect(MARGIN, bottom_y, CONTENT_WIDTH, table_height, COLORS[:white])
    stroke_rect(MARGIN, bottom_y, CONTENT_WIDTH, table_height, COLORS[:line])
    fill_rect(MARGIN, top_y - header_height, CONTENT_WIDTH, header_height, COLORS[:heading])

    column_starts = column_starts(columns, MARGIN)
    column_ends = column_ends(columns, MARGIN)
    column_ends[0...-1].each { |line_x| stroke_line(line_x, bottom_y, line_x, top_y, COLORS[:line]) }

    y = top_y - header_height
    table_rows.times do
      stroke_line(MARGIN, y, MARGIN + CONTENT_WIDTH, y, COLORS[:line])
      y -= row_height
    end

    columns.each_with_index do |column, index|
      x = column_starts[index] + 6
      add_text(x, top_y - 15, column[:label], size: 9, bold: true, color: COLORS[:muted])
    end

    visible_rows.each_with_index do |row, index|
      baseline = top_y - header_height - (index * row_height) - 12
      columns.each_with_index do |column, column_index|
        if column[:key] == :total
          add_text_right(column_ends[column_index] - 6, baseline, money(row[:total]), size: 9, bold: true)
        else
          max_chars = column[:key] == :description ? (quotation.show_track_details? ? 42 : 50) : 16
          add_text(column_starts[column_index] + 6, baseline, truncate(row[column[:key]], max_chars), size: 9)
        end
      end
    end

    if has_omitted
      baseline = top_y - header_height - (visible_rows.size * row_height) - 12
      omitted_count = quotation.rows.size - MAX_ROWS
      add_text(
        MARGIN + 8,
        baseline,
        "#{omitted_count} additional row(s) omitted in this one-page PDF.",
        size: 9,
        color: COLORS[:muted]
      )
    end

    bottom_y
  end

  def draw_totals_block(top_y)
    row_height = 18
    block_width = 228
    block_height = row_height * 3
    x = MARGIN + CONTENT_WIDTH - block_width
    bottom_y = top_y - block_height

    fill_rect(x, bottom_y, block_width, block_height, COLORS[:panel])
    stroke_rect(x, bottom_y, block_width, block_height, COLORS[:line])
    stroke_line(x, top_y - row_height, x + block_width, top_y - row_height, COLORS[:line])
    stroke_line(x, top_y - (row_height * 2), x + block_width, top_y - (row_height * 2), COLORS[:line])

    rows = [
      [ "TOTAL (ex GST)", quotation.total_ex_gst, true ],
      [ "GST", quotation.gst, false ],
      [ "TOTAL (inc GST)", quotation.total_inc_gst, true ]
    ]

    rows.each_with_index do |(label, amount, emphasize), index|
      baseline = top_y - (index * row_height) - 12
      add_text(x + 8, baseline, label, size: 9, bold: emphasize, color: COLORS[:muted])
      add_text_right(x + block_width - 8, baseline, money(amount), size: 9, bold: true)
    end

    bottom_y
  end

  def draw_bank_details_block(top_y)
    details = quotation.bank_details
    block_height = 112
    bottom_y = top_y - block_height

    fill_rect(MARGIN, bottom_y, CONTENT_WIDTH, block_height, COLORS[:white])
    stroke_rect(MARGIN, bottom_y, CONTENT_WIDTH, block_height, COLORS[:line])

    add_text(MARGIN + 10, top_y - 14, "Bank details", size: 10, bold: true, color: COLORS[:muted])
    add_text(MARGIN + 10, top_y - 29, "Account name: #{details[:account_name]}", size: 9)
    add_text(MARGIN + 10, top_y - 42, "Bank name: #{details[:bank_name]}", size: 9)
    add_text(MARGIN + 10, top_y - 55, "BSB: #{details[:bsb]}", size: 9)
    add_text(MARGIN + 10, top_y - 68, "Account number: #{details[:account_number]}", size: 9)
    add_text(MARGIN + 10, top_y - 84, "Terms: #{truncate(OrderDocumentCopy.terms, 88)}", size: 8, color: COLORS[:muted])
    add_text(MARGIN + 10, top_y - 97, truncate(OrderDocumentCopy.footer, 98), size: 8, color: COLORS[:muted])
  end

  def customer_contact_line
    [ quotation.customer_email, quotation.customer_phone ].reject(&:blank?).join(" / ")
  end

  def column_starts(columns, x_origin)
    running = x_origin
    columns.map do |column|
      start = running
      running += column[:width]
      start
    end
  end

  def column_ends(columns, x_origin)
    running = x_origin
    columns.map do |column|
      running += column[:width]
      running
    end
  end

  def quotation
    @quotation
  end

  def fill_rect(x, y, width, height, color)
    @commands << "#{color.join(' ')} rg #{x.round(2)} #{y.round(2)} #{width.round(2)} #{height.round(2)} re f"
  end

  def stroke_rect(x, y, width, height, color)
    @commands << "#{color.join(' ')} RG 0.75 w #{x.round(2)} #{y.round(2)} #{width.round(2)} #{height.round(2)} re S"
  end

  def stroke_line(x1, y1, x2, y2, color)
    @commands << "#{color.join(' ')} RG 0.6 w #{x1.round(2)} #{y1.round(2)} m #{x2.round(2)} #{y2.round(2)} l S"
  end

  def money(value)
    format("%s %.2f", @quote_request.currency, value.to_d)
  end

  def safe_date(value)
    I18n.l(value, format: :long)
  rescue StandardError
    value.to_s
  end

  def truncate(text, max_chars)
    value = text.to_s
    return value if value.length <= max_chars

    "#{value[0, max_chars - 3]}..."
  end

  def add_text(x, y, value, size:, bold: false, color: COLORS[:ink])
    font_ref = bold ? "/F2" : "/F1"
    @commands << "#{color.join(' ')} rg BT #{font_ref} #{size} Tf #{x.round(2)} #{y.round(2)} Td (#{escape_pdf_text(value)}) Tj ET"
  end

  def add_text_right(x_right, y, value, size:, bold: false, color: COLORS[:ink])
    text = value.to_s
    estimated_width = (text.length * size * 0.52)
    x = x_right - estimated_width
    add_text(x, y, text, size: size, bold: bold, color: color)
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
