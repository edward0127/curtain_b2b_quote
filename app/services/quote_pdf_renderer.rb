class QuotePdfRenderer
  PAGE_WIDTH = 595
  PAGE_HEIGHT = 842
  MARGIN = 40
  CONTENT_WIDTH = PAGE_WIDTH - (MARGIN * 2)
  MAX_ITEM_ROWS = 11

  COLORS = {
    ink: [0.071, 0.204, 0.278],
    muted: [0.302, 0.396, 0.459],
    line: [0.851, 0.898, 0.925],
    panel: [0.976, 0.988, 0.996],
    accent: [0.043, 0.518, 0.702],
    white: [1.0, 1.0, 1.0]
  }.freeze

  def initialize(quote_request)
    @quote_request = quote_request
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
    y = 802

    add_text(MARGIN, y, @quote_request.quote_template.heading.to_s, size: 22, font: :bold, color: COLORS[:ink])
    y -= 28
    add_text(MARGIN, y, "Quote Number: #{@quote_request.quote_number}", size: 11, color: COLORS[:muted])
    y -= 16
    add_text(MARGIN, y, "Customer: #{@quote_request.user.email}", size: 11, color: COLORS[:muted])
    y -= 26

    y = draw_summary_panel(y)
    y -= 24

    add_text(MARGIN, y, "Line Items", size: 13, font: :bold, color: COLORS[:ink])
    y -= 14

    y = draw_items_table(y)
    y -= 18

    y = draw_total_bar(y)
    y -= 16

    y = draw_notes_panel(y)
    y -= 14

    draw_terms_and_footer(y)
  end

  def draw_summary_panel(top_y)
    panel_height = 106
    bottom_y = top_y - panel_height

    fill_rect(MARGIN, bottom_y, CONTENT_WIDTH, panel_height, COLORS[:panel])
    stroke_rect(MARGIN, bottom_y, CONTENT_WIDTH, panel_height, COLORS[:line])

    left_x = MARGIN + 12
    right_x = MARGIN + (CONTENT_WIDTH / 2.0) + 8
    row_y = top_y - 20

    add_text(left_x, row_y, "Status", size: 10, font: :bold, color: COLORS[:muted])
    add_text(left_x + 72, row_y, @quote_request.status.humanize, size: 10, color: COLORS[:ink])

    row_y -= 18
    add_text(left_x, row_y, "Valid Until", size: 10, font: :bold, color: COLORS[:muted])
    add_text(left_x + 72, row_y, safe_date(@quote_request.valid_until), size: 10, color: COLORS[:ink])

    row_y -= 18
    add_text(left_x, row_y, "Reference", size: 10, font: :bold, color: COLORS[:muted])
    add_text(left_x + 72, row_y, truncate(@quote_request.customer_reference.presence || "N/A", 28), size: 10, color: COLORS[:ink])

    row_y = top_y - 20
    add_text(right_x, row_y, "Template", size: 10, font: :bold, color: COLORS[:muted])
    add_text(right_x + 70, row_y, truncate(@quote_request.quote_template.heading.to_s, 24), size: 10, color: COLORS[:ink])

    row_y -= 18
    add_text(right_x, row_y, "Items", size: 10, font: :bold, color: COLORS[:muted])
    add_text(right_x + 70, row_y, @quote_request.line_items_count.to_s, size: 10, color: COLORS[:ink])

    row_y -= 18
    add_text(right_x, row_y, "Quote Total", size: 10, font: :bold, color: COLORS[:muted])
    add_text(right_x + 70, row_y, money(@quote_request.total), size: 10, font: :bold, color: COLORS[:ink])

    bottom_y
  end

  def draw_items_table(top_y)
    col_widths = [28, 165, 98, 40, 92, 92]
    col_x = column_positions(col_widths)
    header_h = 24
    row_h = 22

    fill_rect(MARGIN, top_y - header_h, CONTENT_WIDTH, header_h, COLORS[:accent])
    add_table_headers(col_x, top_y - 16)

    y = top_y - header_h
    visible_items = @quote_request.quote_items.first(MAX_ITEM_ROWS)

    visible_items.each_with_index do |item, index|
      row_bottom = y - row_h
      fill_color = index.even? ? COLORS[:white] : COLORS[:panel]
      fill_rect(MARGIN, row_bottom, CONTENT_WIDTH, row_h, fill_color)
      stroke_rect(MARGIN, row_bottom, CONTENT_WIDTH, row_h, COLORS[:line])

      baseline = row_bottom + 8
      add_text(col_x[0], baseline, (index + 1).to_s, size: 9, color: COLORS[:ink])
      add_text(col_x[1], baseline, truncate(item.product.name, 28), size: 9, color: COLORS[:ink])
      add_text(col_x[2], baseline, truncate(item_dimension(item), 18), size: 9, color: COLORS[:ink])
      add_text(col_x[3], baseline, item.quantity.to_i.to_s, size: 9, color: COLORS[:ink])
      add_text(col_x[4], baseline, money(item.unit_price), size: 9, color: COLORS[:ink])
      add_text(col_x[5], baseline, money(item.line_total), size: 9, font: :bold, color: COLORS[:ink])

      y = row_bottom
    end

    if @quote_request.quote_items.size > MAX_ITEM_ROWS
      warning_h = 18
      row_bottom = y - warning_h
      fill_rect(MARGIN, row_bottom, CONTENT_WIDTH, warning_h, COLORS[:panel])
      stroke_rect(MARGIN, row_bottom, CONTENT_WIDTH, warning_h, COLORS[:line])
      remaining = @quote_request.quote_items.size - MAX_ITEM_ROWS
      add_text(MARGIN + 10, row_bottom + 6, "#{remaining} additional item(s) not shown in this one-page PDF.", size: 9, color: COLORS[:muted])
      y = row_bottom
    end

    y
  end

  def add_table_headers(col_x, baseline)
    headers = [ "#", "Product", "Dimensions", "Qty", "Unit Price", "Line Total" ]
    headers.each_with_index do |heading, index|
      add_text(col_x[index], baseline, heading, size: 9, font: :bold, color: COLORS[:white])
    end
  end

  def draw_total_bar(top_y)
    bar_h = 30
    bottom_y = top_y - bar_h
    fill_rect(MARGIN, bottom_y, CONTENT_WIDTH, bar_h, COLORS[:panel])
    stroke_rect(MARGIN, bottom_y, CONTENT_WIDTH, bar_h, COLORS[:line])

    add_text(MARGIN + 12, bottom_y + 10, "Quote Total", size: 11, font: :bold, color: COLORS[:ink])
    add_text(PAGE_WIDTH - MARGIN - 145, bottom_y + 10, money(@quote_request.total), size: 11, font: :bold, color: COLORS[:ink])
    bottom_y
  end

  def draw_notes_panel(top_y)
    title_y = top_y
    add_text(MARGIN, title_y, "Notes", size: 11, font: :bold, color: COLORS[:muted])

    note_lines = wrap_text(@quote_request.notes.presence || "No additional notes provided.", 92).first(5)
    panel_h = [58, (note_lines.size * 12) + 18].max
    panel_top = title_y - 8
    panel_bottom = panel_top - panel_h

    fill_rect(MARGIN, panel_bottom, CONTENT_WIDTH, panel_h, COLORS[:white])
    stroke_rect(MARGIN, panel_bottom, CONTENT_WIDTH, panel_h, COLORS[:line])

    text_y = panel_top - 14
    note_lines.each do |line|
      add_text(MARGIN + 10, text_y, line, size: 9, color: COLORS[:ink])
      text_y -= 12
    end

    panel_bottom
  end

  def draw_terms_and_footer(top_y)
    terms_lines = wrap_text(@quote_request.quote_template.terms.presence || "Quote valid for 14 days unless otherwise stated.", 96).first(3)
    footer_lines = wrap_text(@quote_request.quote_template.footer.presence || "Please contact us to proceed with this quote.", 96).first(2)

    y = [top_y, 132].max
    add_text(MARGIN, y, "Terms", size: 10, font: :bold, color: COLORS[:muted])
    y -= 13

    terms_lines.each do |line|
      add_text(MARGIN, y, line, size: 9, color: COLORS[:muted])
      y -= 11
    end

    y -= 4
    footer_lines.each do |line|
      add_text(MARGIN, y, line, size: 9, color: COLORS[:muted])
      y -= 11
    end
  end

  def add_text(x, y, value, size:, font: :regular, color: COLORS[:ink])
    font_ref = font == :bold ? "/F2" : "/F1"
    @commands << "#{color.join(' ')} rg BT #{font_ref} #{size} Tf #{x.round(2)} #{y.round(2)} Td (#{escape_pdf_text(value)}) Tj ET"
  end

  def fill_rect(x, y, width, height, color)
    @commands << "#{color.join(' ')} rg #{x.round(2)} #{y.round(2)} #{width.round(2)} #{height.round(2)} re f"
  end

  def stroke_rect(x, y, width, height, color)
    @commands << "#{color.join(' ')} RG 0.75 w #{x.round(2)} #{y.round(2)} #{width.round(2)} #{height.round(2)} re S"
  end

  def column_positions(col_widths)
    running = MARGIN + 8
    col_widths.map do |width|
      x = running
      running += width
      x
    end
  end

  def item_dimension(item)
    return "Unit priced" unless item.product.per_square_meter?

    "#{item.width}x#{item.height}cm"
  end

  def truncate(text, max_chars)
    value = text.to_s
    return value if value.length <= max_chars

    "#{value[0, max_chars - 3]}..."
  end

  def wrap_text(text, max_chars)
    words = text.to_s.split(/\s+/)
    return [ "" ] if words.empty?

    lines = []
    line = +""

    words.each do |word|
      if line.empty?
        line = word
      elsif (line.length + 1 + word.length) <= max_chars
        line << " #{word}"
      else
        lines << line
        line = word
      end
    end
    lines << line if line.present?
    lines
  end

  def safe_date(value)
    return "N/A" if value.blank?

    I18n.l(value, format: :long)
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
