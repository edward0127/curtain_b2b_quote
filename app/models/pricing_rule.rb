class PricingRule < ApplicationRecord
  belongs_to :product

  enum :adjustment_type, { percentage: 0, fixed_amount: 1, set_unit_price: 2 }

  validates :name, presence: true
  validates :priority, numericality: { only_integer: true }
  validates :adjustment_value, numericality: true
  validates :min_quantity, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :max_quantity, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :min_area, :max_area, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :max_area_not_less_than_min_area
  validate :max_quantity_not_less_than_min_quantity

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:priority, :id) }

  def applies_to?(area_sqm:, quantity:)
    return false if min_area.present? && area_sqm < min_area
    return false if max_area.present? && area_sqm > max_area
    return false if min_quantity.present? && quantity < min_quantity
    return false if max_quantity.present? && quantity > max_quantity

    true
  end

  def apply_to(unit_price)
    candidate = case adjustment_type
    when "percentage"
      unit_price * (1 + adjustment_value.to_d / 100)
    when "fixed_amount"
      unit_price + adjustment_value.to_d
    when "set_unit_price"
      adjustment_value.to_d
    else
      unit_price
    end

    [ candidate, 0.to_d ].max
  end

  private

  def max_area_not_less_than_min_area
    return unless min_area.present? && max_area.present? && max_area < min_area

    errors.add(:max_area, "must be greater than or equal to min area")
  end

  def max_quantity_not_less_than_min_quantity
    return unless min_quantity.present? && max_quantity.present? && max_quantity < min_quantity

    errors.add(:max_quantity, "must be greater than or equal to min quantity")
  end
end
