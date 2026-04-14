class QuoteItem < ApplicationRecord
  belongs_to :quote_request
  belongs_to :product

  enum :opening_type, {
    single_open: 0,
    double_open: 1
  }, prefix: true

  enum :finished_floor_mode, {
    just_off_floor: 0,
    puddled: 1
  }, prefix: true

  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :width, :height, numericality: { greater_than: 0 }, if: :requires_dimensions?

  before_validation :normalize_quantity
  before_validation :calculate_pricing_snapshot

  scope :ordered, -> { order(:line_position, :id) }

  def requires_dimensions?
    product&.per_square_meter?
  end

  def legacy_separate_track?
    return true if track_price.to_d.positive?
    return true if track_metres_required.to_i.positive?

    separate_track_code.present?
  end

  alias_method :legacy_track_details?, :legacy_separate_track?
  alias_method :show_track_details?, :legacy_separate_track?

  def active_curtain_only_pricing?
    order_snapshot? && !show_track_details?
  end

  def line_location_label(blank: "-")
    location_name.presence || blank
  end

  def product_line_label(blank: "-")
    base = product&.product_type.presence || product&.name.presence
    label = [ base, product&.style_name.presence ].compact.join(" - ")
    label.presence || blank
  end

  def style_label(blank: "-")
    product&.style_name.presence || product&.product_type.presence || blank
  end

  def pinch_pleat_style?
    product&.style_name.to_s.casecmp("Pinch Pleat").zero? ||
      style_label(blank: "").casecmp("Pinch Pleat").zero?
  end

  def material_label(blank: "-")
    material_name.presence || product&.product_type.presence || product&.name.presence || blank
  end

  def material_with_number_label(blank: "-")
    label = [ material_label(blank: nil), material_number.presence ].compact.join(" ")
    label.presence || blank
  end

  def width_mm_label(blank: "-")
    positive_number_label(width_mm, blank: blank)
  end

  def ceiling_drop_mm_label(blank: "-")
    positive_number_label(ceiling_drop_mm, blank: blank)
  end

  def factory_drop_mm_label(blank: "-")
    positive_number_label(factory_drop_mm.presence || ceiling_drop_mm, blank: blank)
  end

  def finished_floor_label(blank: "-")
    case finished_floor_mode
    when "puddled" then "Puddled"
    when "just_off_floor" then "Just off"
    else blank
    end
  end

  def opening_count_label(blank: "-")
    return blank if opening_type.blank?

    opening_type == "double_open" ? "2" : "1"
  end

  def opening_code_label(blank: "")
    code = opening_code.presence || default_opening_code
    code.presence || blank
  end

  def separate_track_code(blank: "")
    track = normalized_track_selected
    track.presence || blank
  end

  def track_length_label(blank: "")
    return blank unless show_track_details?

    width_mm_label(blank: blank)
  end

  def hooks_label(blank: "-")
    hooks_display.presence || hooks_total.presence || blank
  end

  def brackets_label(blank: "")
    positive_number_label(brackets_total, blank: blank)
  end

  def wand_label(blank: "-")
    return wand_quantity.to_i.to_s if wand_quantity.to_i.positive?
    return "Y" if wand_required

    blank
  end

  private

  def normalize_quantity
    self.quantity = [ quantity.to_i, 1 ].max
  end

  def calculate_pricing_snapshot
    return unless product
    return if order_v2_snapshot?

    self.area_sqm = requires_dimensions? ? computed_area_sqm : 0
    base_unit_price = product.per_square_meter? ? area_sqm.to_d * product.base_price.to_d : product.base_price.to_d

    pricing_result = QuotePricingEngine.new(
      product: product,
      area_sqm: area_sqm,
      quantity: quantity
    ).calculate(base_unit_price: base_unit_price)

    self.unit_price = pricing_result.unit_price.round(2)
    self.line_total = (unit_price.to_d * quantity.to_i).round(2)
    self.applied_rule_names = pricing_result.applied_rule_names.join(", ")
    self.description = product.name if description.blank?
  end

  def computed_area_sqm
    ((width.to_d * height.to_d) / 10_000).round(3)
  end

  def order_snapshot?
    width_mm.present? && ceiling_drop_mm.present?
  end

  alias_method :order_v2_snapshot?, :order_snapshot?

  def normalized_track_selected
    selected = track_selected.to_s.strip
    return "" if selected.blank? || selected.casecmp("none").zero?

    selected
  end

  def default_opening_code
    opening_type == "double_open" ? "C/O" : "OW"
  end

  def positive_number_label(value, blank:)
    numeric = value.to_i
    numeric.positive? ? numeric.to_s : blank
  end
end
