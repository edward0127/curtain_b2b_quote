module ApplicationHelper
  def quote_or_order_label(count: 1, capitalize: true)
    noun = "order"
    noun = noun.pluralize if count.to_i != 1
    capitalize ? noun.capitalize : noun
  end

  def site_setting(key)
    return AppSetting::DEFAULTS.fetch(key) unless app_setting.respond_to?(key)

    value = app_setting.public_send(key)
    value.presence || AppSetting::DEFAULTS.fetch(key)
  end

  def public_font_class(key)
    selected = site_setting(key).to_s
    allowed = AppSetting::PUBLIC_FONT_STACKS.keys
    allowed.include?(selected) ? selected : AppSetting::DEFAULTS.fetch(key)
  end

  def public_text_style(styles, key)
    style_hash = styles.is_a?(Hash) ? styles[key.to_s] : nil
    return nil unless style_hash.is_a?(Hash)

    declarations = []

    style_hash.each do |raw_key, raw_value|
      key_name = raw_key.to_s
      value = raw_value.to_s.strip
      next if value.blank?

      case key_name
      when "font_size"
        css_value = normalize_css_size(value)
        declarations << "font-size: #{css_value}" if css_value
      when "color"
        declarations << "color: #{value}" if value.match?(/\A[#(),.%\-\s\w]+\z/)
      when "font_weight"
        declarations << "font-weight: #{value}" if value.match?(/\A(normal|bold|bolder|lighter|[1-9]00)\z/i)
      when "font_style"
        declarations << "font-style: #{value}" if value.match?(/\A(normal|italic|oblique)\z/i)
      when "text_align"
        declarations << "text-align: #{value}" if value.match?(/\A(left|right|center|justify|start|end)\z/i)
      when "text_transform"
        declarations << "text-transform: #{value}" if value.match?(/\A(none|uppercase|lowercase|capitalize)\z/i)
      when "letter_spacing"
        css_value = normalize_css_size(value)
        declarations << "letter-spacing: #{css_value}" if css_value
      when "line_height"
        declarations << "line-height: #{value}" if value.match?(/\A\d+(\.\d+)?(px|rem|em|%)?\z/i)
      when "font_family"
        family = AppSetting::PUBLIC_FONT_STACKS[value] || AppSetting::PUBLIC_FONT_STACKS[value.to_s]
        declarations << "font-family: #{family}" if family
      end
    end

    declarations.join("; ").presence
  end

  private

  def normalize_css_size(value)
    return "#{value}px" if value.match?(/\A\d+(\.\d+)?\z/)
    return value if value.match?(/\A\d+(\.\d+)?(px|rem|em|%)\z/i)

    nil
  end
end
