module Inventory
  class StockDeductor
    COMPONENT_REQUIREMENTS = {
      track_inventory_item_id: :track_metres_required,
      hook_inventory_item_id: :hooks_total,
      bracket_inventory_item_id: :brackets_total,
      wand_inventory_item_id: :wand_quantity,
      end_cap_inventory_item_id: :end_cap_quantity,
      stopper_inventory_item_id: :stopper_quantity,
      wand_hook_inventory_item_id: :wand_hook_quantity
    }.freeze

    def initialize(quote_request:)
      @quote_request = quote_request
    end

    def deduct!
      adjustments = build_adjustments
      return if adjustments.empty?

      InventoryItem.where(id: adjustments.keys).order(:id).each do |item|
        required = adjustments[item.id]
        item.with_lock do
          if item.on_hand < required
            raise ArgumentError, "Insufficient stock for #{item.name}. Required #{required}, available #{item.on_hand}."
          end

          item.on_hand -= required
          item.save!
        end
      end
    end

    private

    attr_reader :quote_request

    def build_adjustments
      adjustments = Hash.new(0)

      quote_request.quote_items.each do |item|
        product = item.product
        next unless product

        COMPONENT_REQUIREMENTS.each do |association_key, requirement_key|
          inventory_item_id = product.public_send(association_key)
          next if inventory_item_id.blank?

          required_per_unit = item.public_send(requirement_key).to_i
          next if required_per_unit <= 0

          adjustments[inventory_item_id] += required_per_unit * item.quantity.to_i
        end
      end

      adjustments
    end
  end
end
