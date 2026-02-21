class QuotePricingEngine
  Result = Struct.new(:unit_price, :applied_rule_names, keyword_init: true)

  def initialize(product:, area_sqm:, quantity:)
    @product = product
    @area_sqm = area_sqm.to_d
    @quantity = quantity.to_i
  end

  def calculate(base_unit_price:)
    current_price = base_unit_price.to_d
    applied_rule_names = []

    @product.pricing_rules.active.ordered.each do |rule|
      next unless rule.applies_to?(area_sqm: @area_sqm, quantity: @quantity)

      current_price = rule.apply_to(current_price)
      applied_rule_names << rule.name
    end

    Result.new(
      unit_price: [ current_price, 0.to_d ].max,
      applied_rule_names: applied_rule_names
    )
  end
end
