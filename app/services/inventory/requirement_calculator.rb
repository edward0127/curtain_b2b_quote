module Inventory
  class RequirementCalculator
    Result = Struct.new(
      :track_metres_required,
      :brackets_total,
      :hooks_total,
      :hooks_display,
      :factory_drop_mm,
      keyword_init: true
    )

    def initialize(width_mm:, opening_type:, ceiling_drop_mm:, finished_floor_mode:)
      @width_mm = width_mm.to_i
      @opening_type = opening_type.to_s
      @ceiling_drop_mm = ceiling_drop_mm.to_i
      @finished_floor_mode = finished_floor_mode.to_s
    end

    def calculate
      hooks_total, hooks_display = hooks_values

      Result.new(
        track_metres_required: 0,
        brackets_total: [ 2, (width_mm / 500.0).floor ].max,
        hooks_total: hooks_total,
        hooks_display: hooks_display,
        factory_drop_mm: factory_drop_value
      )
    end

    private

    attr_reader :width_mm, :opening_type, :ceiling_drop_mm, :finished_floor_mode

    def hooks_values
      if opening_type == "double_open"
        total = ceil_to_multiple((width_mm / 54.0) + 1, 4)
        half = total / 2
        return [ total, "#{half} and #{half}" ]
      end

      rounded = (width_mm / 54.0).round(0)
      total = ceil_to_multiple(rounded + 1, 2)
      [ total, total.to_s ]
    end

    def ceil_to_multiple(value, multiple)
      ((value.to_f / multiple).ceil * multiple).to_i
    end

    def factory_drop_value
      return ceiling_drop_mm if finished_floor_mode == "puddled"

      [ ceiling_drop_mm - 40, 0 ].max
    end
  end
end
