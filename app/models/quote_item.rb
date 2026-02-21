class QuoteItem < ApplicationRecord
  belongs_to :quote_request
  belongs_to :product

  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :width, :height, numericality: { greater_than: 0 }, if: :requires_dimensions?

  before_validation :normalize_quantity
  before_validation :calculate_pricing_snapshot

  scope :ordered, -> { order(:line_position, :id) }

  def requires_dimensions?
    product&.per_square_meter?
  end

  private

  def normalize_quantity
    self.quantity = [ quantity.to_i, 1 ].max
  end

  def calculate_pricing_snapshot
    return unless product

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
end
