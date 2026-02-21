class Product < ApplicationRecord
  has_many :pricing_rules, -> { order(:priority, :id) }, dependent: :destroy
  has_many :quote_items, dependent: :restrict_with_error

  enum :pricing_mode, { per_square_meter: 0, per_unit: 1 }

  validates :name, presence: true
  validates :base_price, numericality: { greater_than_or_equal_to: 0 }
  validates :sku, uniqueness: true, allow_blank: true

  scope :active, -> { where(active: true) }
  scope :alphabetical, -> { order(:name) }
end
