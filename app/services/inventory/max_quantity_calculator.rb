module Inventory
  class MaxQuantityCalculator
    Result = Struct.new(
      :max_quantity,
      :adjusted_quantity,
      :adjusted,
      :limiting_component,
      keyword_init: true
    )

    REQUIREMENT_MAP = {
      track_inventory_item: :track_metres_required,
      hook_inventory_item: :hooks_total,
      bracket_inventory_item: :brackets_total,
      wand_inventory_item: :wand_quantity,
      end_cap_inventory_item: :end_cap_quantity,
      stopper_inventory_item: :stopper_quantity,
      wand_hook_inventory_item: :wand_hook_quantity
    }.freeze

    def initialize(product:, requirement_per_unit:, requested_quantity: nil)
      @product = product
      @requirement_per_unit = requirement_per_unit.to_h.symbolize_keys
      @requested_quantity = requested_quantity
    end

    def calculate
      capacity = component_capacity

      if capacity.empty?
        max_quantity = requested_quantity.present? ? requested_quantity.to_i : 0
        return build_result(max_quantity, nil)
      end

      limiting_pair = capacity.min_by { |_assoc, details| details[:max] }
      max_quantity = limiting_pair.last[:max]
      limiting_component = limiting_pair.last[:name]

      build_result(max_quantity, limiting_component)
    end

    private

    attr_reader :product, :requirement_per_unit, :requested_quantity

    def component_capacity
      REQUIREMENT_MAP.each_with_object({}) do |(association, requirement_key), memo|
        item = product.public_send(association)
        required = requirement_per_unit.fetch(requirement_key, 0).to_i
        next if item.blank? || required <= 0

        memo[association] = {
          max: item.on_hand.to_i / required,
          name: item.name
        }
      end
    end

    def build_result(max_quantity, limiting_component)
      requested = requested_quantity.present? ? requested_quantity.to_i : max_quantity
      adjusted_quantity = [ requested, max_quantity ].min

      Result.new(
        max_quantity: max_quantity,
        adjusted_quantity: adjusted_quantity,
        adjusted: requested_quantity.present? && adjusted_quantity < requested,
        limiting_component: limiting_component
      )
    end
  end
end
