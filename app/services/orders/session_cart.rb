module Orders
  class SessionCart
    SESSION_KEY = "orders_v2_b2b_cart".freeze

    def initialize(session:)
      @session = session
      @data = normalized_data(session[SESSION_KEY])
    end

    def lines
      @data["lines"]
    end

    def empty?
      lines.empty?
    end

    def total
      lines.sum { |line| line.fetch("line_total", 0).to_d }.round(2)
    end

    def add_line(line_hash)
      lines << stringify_keys(line_hash)
      persist!
    end

    def replace_line(line_id, line_hash)
      index = lines.index { |line| line["id"].to_s == line_id.to_s }
      return false unless index

      lines[index] = stringify_keys(line_hash)
      persist!
      true
    end

    def remove_line(line_id)
      before = lines.size
      lines.reject! { |line| line["id"].to_s == line_id.to_s }
      changed = lines.size != before
      persist! if changed
      changed
    end

    def clear
      @data = { "lines" => [] }
      persist!
    end

    def replace_lines(new_lines)
      @data["lines"] = Array(new_lines).map { |line| stringify_keys(line) }
      persist!
    end

    def persist!
      session[SESSION_KEY] = @data
    end

    private

    attr_reader :session

    def normalized_data(raw_value)
      hash = raw_value.is_a?(Hash) ? raw_value : {}
      lines = hash["lines"]
      lines = [] unless lines.is_a?(Array)
      { "lines" => lines.map { |line| stringify_keys(line) } }
    end

    def stringify_keys(value)
      return value unless value.is_a?(Hash)

      value.each_with_object({}) do |(key, item), memo|
        memo[key.to_s] = item
      end
    end
  end
end
