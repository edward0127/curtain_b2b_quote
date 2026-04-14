class Product < ApplicationRecord
  PRICEBOOK_TEMPLATE_SKU_PREFIX = "PB-".freeze
  PRICING_CHANNELS = %w[b2b b2c].freeze

  has_many :pricing_rules, -> { order(:priority, :id) }, dependent: :destroy
  has_many :quote_items, dependent: :restrict_with_error
  belongs_to :track_inventory_item, class_name: "InventoryItem", optional: true
  belongs_to :hook_inventory_item, class_name: "InventoryItem", optional: true
  belongs_to :bracket_inventory_item, class_name: "InventoryItem", optional: true
  belongs_to :wand_inventory_item, class_name: "InventoryItem", optional: true
  belongs_to :end_cap_inventory_item, class_name: "InventoryItem", optional: true
  belongs_to :stopper_inventory_item, class_name: "InventoryItem", optional: true
  belongs_to :wand_hook_inventory_item, class_name: "InventoryItem", optional: true

  enum :pricing_mode, { per_square_meter: 0, per_unit: 1 }

  validates :name, presence: true
  validates :base_price, numericality: { greater_than_or_equal_to: 0 }
  validates :sku, uniqueness: true, allow_blank: true
  validates :pricing_channel, inclusion: { in: PRICING_CHANNELS }, allow_blank: true
  validates :product_type, :style_name, presence: true, if: :pricing_channel_present?

  scope :active, -> { where(active: true) }
  scope :alphabetical, -> { order(:name) }
  scope :imported_pricebook_templates, -> { where("products.sku LIKE ?", "#{PRICEBOOK_TEMPLATE_SKU_PREFIX}%") }
  scope :archived_imported_pricebook_templates, -> { imported_pricebook_templates.where(active: false) }
  scope :visible_in_admin_default_list, -> { where.not(id: archived_imported_pricebook_templates.select(:id)) }
  scope :orderable_for_channel, ->(channel) do
    normalized = channel.to_s.downcase

    if PRICING_CHANNELS.include?(normalized)
      active
        .where(pricing_channel: normalized)
        .joins("INNER JOIN price_matrix_entries ON price_matrix_entries.channel = products.pricing_channel AND price_matrix_entries.product_name = products.product_type AND price_matrix_entries.style_name = products.style_name")
        .distinct
        .alphabetical
    else
      none
    end
  end

  def matrix_priced_template?
    pricing_channel.present? && product_type.present? && style_name.present?
  end

  def matrix_price_ready?
    return false unless matrix_priced_template?

    PriceMatrixEntry.exists?(
      channel: pricing_channel,
      product_name: product_type,
      style_name: style_name
    )
  end

  def legacy_custom_curtain?
    name.to_s.casecmp("Custom Curtain Legacy").zero?
  end

  def imported_pricebook_template?
    sku.to_s.start_with?(PRICEBOOK_TEMPLATE_SKU_PREFIX)
  end

  def archived_imported_pricebook_template?
    imported_pricebook_template? && !active?
  end

  def matrix_lookup_name
    product_type.presence || name.to_s.split(" (").first
  end

  private

  def pricing_channel_present?
    pricing_channel.present?
  end
end
