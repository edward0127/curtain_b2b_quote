class FactorySheetPdfRenderer
  PAGE_WIDTH = 842
  PAGE_HEIGHT = 595
  MARGIN = 18
  CONTENT_WIDTH = PAGE_WIDTH - (MARGIN * 2)

  META_ROW_HEIGHT = 24
  SECTION_HEIGHT = 22
  HEADER_HEIGHT = 44
  DATA_ROW_HEIGHT = 14
  FIXED_ROWS = 11
  META_TO_SECTION_GAP = 4
  SECTION_GAP = 4
  NOTES_TOP_GAP = 0

  COLORS = {
    page: [1.0, 1.0, 1.0],
    ink: [0.0, 0.0, 0.0],
    line: [0.15, 0.15, 0.15],
    section: [0.980, 0.690, 0.0],
    header: [0.67, 0.72, 0.82]
  }.freeze

  FIRST_TABLE_COLUMNS = [
    { key: :line_no, label: "No.", width: 22, align: :center },
    { key: :location, label: "Location\n(\u4f4d\u5b50)", width: 72, align: :left },
    { key: :style, label: "Style\n(\u6b3e\u5f0f)\n\u86c7\u5f62/\u97e9\u54f2", width: 78, align: :left },
    { key: :material, label: "Material\n(\u5e03\u6599)\n\u7eb1\u7a97/\u906e\u5149", width: 72, align: :left },
    { key: :number, label: "Number\n(\u5e03\u6599\u7f16\u53f7)", width: 66, align: :center },
    { key: :lv_name, label: "LV Name", width: 60, align: :left },
    { key: :width, label: "Width\n(\u5bbd)", width: 44, align: :center },
    { key: :drop, label: "Drop\n(\u9ad8)", width: 44, align: :center },
    { key: :finished, label: "Finished\ndistance from\nfloor (Just off/\nPuddled)", width: 110, align: :center },
    { key: :single_double, label: "\u5355\u5f00 (1) /\n\u53cc\u5f00 (2)", width: 74, align: :center },
    { key: :high_temp, label: "\u9ad8\u6e29\u5b9a\u5236", width: 58, align: :center },
    { key: :clips, label: "Total Clips\n(\u94a9\u5b50)", width: 106, align: :center }
  ].freeze

  SECOND_TABLE_COLUMNS = [
    { key: :opening, label: "Opening", width: 118, align: :center },
    { key: :fixing, label: "FF or TF", width: 118, align: :center },
    { key: :brackets, label: "Backets", width: 102, align: :center },
    { key: :width_notes, label: "Width Notes", width: 170, align: :left },
    { key: :wand, label: "Wand\n(Y/N)", width: 120, align: :center },
    { key: :ceiling_drop, label: "Ceiling Drop", width: 178, align: :center }
  ].freeze

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
      "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 #{PAGE_WIDTH} #{PAGE_HEIGHT}] /Resources << /Font << /F1 4 0 R /F2 5 0 R /F3 6 0 R >> >> /Contents 9 0 R >>",
      "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
      "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>",
      "<< /Type /Font /Subtype /Type0 /BaseFont /STSong-Light /Encoding /UniGB-UCS2-H /DescendantFonts [7 0 R] >>",
      "<< /Type /Font /Subtype /CIDFontType0 /BaseFont /STSong-Light /CIDSystemInfo << /Registry (Adobe) /Ordering (GB1) /Supplement 4 >> /DW 1000 /FontDescriptor 8 0 R >>",
      "<< /Type /FontDescriptor /FontName /STSong-Light /Flags 4 /FontBBox [-25 -254 1000 880] /ItalicAngle 0 /Ascent 880 /Descent -120 /CapHeight 700 /StemV 80 >>",
      "<< /Length #{content_stream.bytesize} >>\nstream\n#{content_stream}\nendstream"
    ]

    assemble_pdf(objects)
  end

  private

  attr_reader :quote_request

  def draw_document
    fill_rect(0, 0, PAGE_WIDTH, PAGE_HEIGHT, COLORS[:page])

    top_y = PAGE_HEIGHT - MARGIN
    add_text((PAGE_WIDTH / 2.0) - 88, top_y - 4, "ORDER FORM 2026", size: 14, bold: true)
    top_y -= 24

    top_y = draw_meta_table(top_y)
    top_y -= META_TO_SECTION_GAP

    first_rows = build_first_table_rows
    top_y = draw_section_table(
      top_y: top_y,
      title: "Fabric details (TO GZ FACTORY)",
      columns: FIRST_TABLE_COLUMNS,
      rows: first_rows
    )

    top_y -= SECTION_GAP

    second_rows = build_second_table_rows
    top_y = draw_section_table(
      top_y: top_y,
      title: "Track details (TO LOCAL FACTORY)",
      columns: SECOND_TABLE_COLUMNS,
      rows: second_rows
    )

    top_y -= NOTES_TOP_GAP
    draw_notes_line(top_y)
  end

  def draw_meta_table(top_y)
    rows = [
      [ "Date\n(\u65e5\u671f)", safe_date(quote_request.submitted_at || quote_request.created_at) ],
      [ "Customer\n(\u5ba2\u6237)", customer_label ],
      [ "Quote\n(\u5355\u53f7)", quote_request.quote_number ]
    ]

    x = MARGIN + 46
    label_width = 132
    value_width = 160
    table_width = label_width + value_width
    table_height = rows.size * META_ROW_HEIGHT
    bottom_y = top_y - table_height

    stroke_rect(x, bottom_y, table_width, table_height, COLORS[:line], line_width: 1.0)
    stroke_line(x + label_width, bottom_y, x + label_width, top_y, COLORS[:line], line_width: 0.8)

    (1...rows.size).each do |index|
      y = top_y - (index * META_ROW_HEIGHT)
      stroke_line(x, y, x + table_width, y, COLORS[:line], line_width: 0.8)
    end

    rows.each_with_index do |(label, value), index|
      row_top = top_y - (index * META_ROW_HEIGHT)
      row_bottom = row_top - META_ROW_HEIGHT
      draw_text_in_cell(x: x, row_top: row_top, row_bottom: row_bottom, width: label_width, value: label, align: :left, bold: true, size: 10)
      draw_text_in_cell(x: x + label_width, row_top: row_top, row_bottom: row_bottom, width: value_width, value: value, align: :left, bold: true, size: 10)
    end

    bottom_y
  end

  def draw_section_table(top_y:, title:, columns:, rows:)
    section_bottom = top_y - SECTION_HEIGHT
    table_top = section_bottom
    table_height = HEADER_HEIGHT + (FIXED_ROWS * DATA_ROW_HEIGHT)
    table_bottom = table_top - table_height

    fill_rect(MARGIN, section_bottom, CONTENT_WIDTH, SECTION_HEIGHT, COLORS[:section])
    stroke_rect(MARGIN, section_bottom, CONTENT_WIDTH, SECTION_HEIGHT, COLORS[:line], line_width: 1.0)
    add_text((PAGE_WIDTH / 2.0) - estimate_text_width(title, 10) / 2.0, top_y - 15, title, size: 10, bold: true)

    fill_rect(MARGIN, table_bottom, CONTENT_WIDTH, table_height, COLORS[:page])
    fill_rect(MARGIN, table_top - HEADER_HEIGHT, CONTENT_WIDTH, HEADER_HEIGHT, COLORS[:header])
    stroke_rect(MARGIN, table_bottom, CONTENT_WIDTH, table_height, COLORS[:line], line_width: 1.0)

    starts = column_starts(columns, MARGIN)
    ends = column_ends(columns, MARGIN)
    ends[0...-1].each do |line_x|
      stroke_line(line_x, table_bottom, line_x, table_top, COLORS[:line], line_width: 0.7)
    end

    line_y = table_top - HEADER_HEIGHT
    FIXED_ROWS.times do
      stroke_line(MARGIN, line_y, MARGIN + CONTENT_WIDTH, line_y, COLORS[:line], line_width: 0.6)
      line_y -= DATA_ROW_HEIGHT
    end

    columns.each_with_index do |column, index|
      draw_text_in_cell(
        x: starts[index],
        row_top: table_top,
        row_bottom: table_top - HEADER_HEIGHT,
        width: column[:width],
        value: column[:label],
        align: :center,
        bold: true,
        size: 7.2
      )
    end

    FIXED_ROWS.times do |index|
      row = rows[index] || {}
      row_top = (table_top - HEADER_HEIGHT) - (index * DATA_ROW_HEIGHT)
      row_bottom = row_top - DATA_ROW_HEIGHT

      columns.each_with_index do |column, column_index|
        value = row[column[:key]] || ""
        draw_text_in_cell(
          x: starts[column_index],
          row_top: row_top,
          row_bottom: row_bottom,
          width: column[:width],
          value: value,
          align: column[:align],
          bold: false,
          size: 7.0
        )
      end
    end

    table_bottom
  end

  def draw_notes_line(top_y)
    note_text = quote_request.notes.to_s.strip
    value = note_text.present? ? "Notes (\u5907\u6ce8): #{note_text}" : "Notes (\u5907\u6ce8):"
    draw_text_in_cell(
      x: MARGIN,
      row_top: top_y,
      row_bottom: top_y - 14,
      width: CONTENT_WIDTH,
      value: value,
      align: :left,
      bold: true,
      size: 9
    )
  end

  def build_first_table_rows
    quote_request.quote_items.first(FIXED_ROWS).each_with_index.map do |item, index|
      {
        line_no: (index + 1).to_s,
        location: item.location_name.presence || "-",
        style: item.product.style_name.presence || item.product.product_type.presence || "-",
        material: item.material_name.presence || item.product.product_type.presence || item.product.name,
        number: item.material_number.presence || "-",
        lv_name: item.lv_name.presence || "-",
        width: numeric_value(item.width_mm),
        drop: numeric_value(item.factory_drop_mm.presence || item.ceiling_drop_mm),
        finished: finished_floor_value(item),
        single_double: item.opening_type == "double_open" ? "2" : "1",
        high_temp: item.high_temp_custom.presence || "-",
        clips: item.hooks_display.presence || numeric_value(item.hooks_total)
      }
    end
  end

  def build_second_table_rows
    quote_request.quote_items.first(FIXED_ROWS).map do |item|
      {
        opening: item.opening_code.presence || default_opening_code(item),
        fixing: item.fixing.presence || "-",
        brackets: numeric_value(item.brackets_total),
        width_notes: item.width_notes.presence || "-",
        wand: wand_value(item),
        ceiling_drop: numeric_value(item.ceiling_drop_mm)
      }
    end
  end

  def draw_text_in_cell(x:, row_top:, row_bottom:, width:, value:, align:, bold:, size:)
    lines = value.to_s.split("\n")
    line_count = [lines.length, 1].max
    line_gap = 0.8
    block_height = line_count * (size + line_gap)
    start_y = row_bottom + ((row_top - row_bottom - block_height) / 2.0) + block_height - size

    lines.each_with_index do |line, index|
      fitted_size = fitted_font_size(line, width - 4, size, 5.0)
      text_width = estimate_text_width(line, fitted_size)
      text_x = case align
      when :center
        x + ((width - text_width) / 2.0)
      when :right
        x + width - text_width - 2
      else
        x + 2
      end

      add_text(text_x, start_y - (index * (size + line_gap)), line, size: fitted_size, bold: bold)
    end
  end

  def fitted_font_size(text, max_width, preferred_size, min_size)
    size = preferred_size.to_f
    while size > min_size && estimate_text_width(text, size) > max_width
      size -= 0.2
    end
    size.round(2)
  end

  def estimate_text_width(text, size)
    text.to_s.each_char.sum do |char|
      char.ascii_only? ? (size * 0.52) : (size * 0.95)
    end
  end

  def finished_floor_value(item)
    return "Puddled" if item.finished_floor_mode == "puddled"
    return "Just off" if item.finished_floor_mode == "just_off_floor"

    "-"
  end

  def wand_value(item)
    return item.wand_quantity.to_i.to_s if item.wand_quantity.to_i.positive?
    return "Y" if item.wand_required

    "-"
  end

  def default_opening_code(item)
    item.opening_type == "double_open" ? "C/O" : "OW"
  end

  def numeric_value(value)
    numeric = value.to_i
    numeric.positive? ? numeric.to_s : "-"
  end

  def customer_label
    quote_request.customer_name.presence || quote_request.user.email
  end

  def safe_date(value)
    I18n.l(value.to_date, format: :default)
  rescue StandardError
    value.to_s
  end

  def column_starts(columns, origin)
    running = origin
    columns.map do |column|
      x = running
      running += column[:width]
      x
    end
  end

  def column_ends(columns, origin)
    running = origin
    columns.map do |column|
      running += column[:width]
      running
    end
  end

  def fill_rect(x, y, width, height, color)
    @commands << "#{color.join(' ')} rg #{x.round(2)} #{y.round(2)} #{width.round(2)} #{height.round(2)} re f"
  end

  def stroke_rect(x, y, width, height, color, line_width: 0.75)
    @commands << "#{color.join(' ')} RG #{line_width} w #{x.round(2)} #{y.round(2)} #{width.round(2)} #{height.round(2)} re S"
  end

  def stroke_line(x1, y1, x2, y2, color, line_width: 0.55)
    @commands << "#{color.join(' ')} RG #{line_width} w #{x1.round(2)} #{y1.round(2)} m #{x2.round(2)} #{y2.round(2)} l S"
  end

  def add_text(x, y, value, size:, bold: false, color: COLORS[:ink])
    text = value.to_s
    if contains_cjk?(text)
      @commands << "#{color.join(' ')} rg BT /F3 #{size} Tf #{x.round(2)} #{y.round(2)} Td <#{utf16_hex(text)}> Tj ET"
      return
    end

    font_ref = bold ? "/F2" : "/F1"
    @commands << "#{color.join(' ')} rg BT #{font_ref} #{size} Tf #{x.round(2)} #{y.round(2)} Td (#{escape_pdf_text(text)}) Tj ET"
  end

  def contains_cjk?(text)
    text.to_s.match?(/[^\u0000-\u007F]/)
  end

  def utf16_hex(text)
    text.to_s.encode("UTF-16BE").unpack1("H*").upcase
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
