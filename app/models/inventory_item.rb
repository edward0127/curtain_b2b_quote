class InventoryItem < ApplicationRecord
  enum :component_type, {
    track: 0,
    hook: 1,
    bracket: 2,
    wand: 3,
    end_cap: 4,
    stopper: 5,
    wand_hook: 6
  }

  has_many :track_products, class_name: "Product", foreign_key: :track_inventory_item_id, dependent: :nullify
  has_many :hook_products, class_name: "Product", foreign_key: :hook_inventory_item_id, dependent: :nullify
  has_many :bracket_products, class_name: "Product", foreign_key: :bracket_inventory_item_id, dependent: :nullify
  has_many :wand_products, class_name: "Product", foreign_key: :wand_inventory_item_id, dependent: :nullify
  has_many :end_cap_products, class_name: "Product", foreign_key: :end_cap_inventory_item_id, dependent: :nullify
  has_many :stopper_products, class_name: "Product", foreign_key: :stopper_inventory_item_id, dependent: :nullify
  has_many :wand_hook_products, class_name: "Product", foreign_key: :wand_hook_inventory_item_id, dependent: :nullify

  validates :name, presence: true
  validates :on_hand, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :sku, uniqueness: true, allow_blank: true

  scope :active, -> { where(active: true) }
end
