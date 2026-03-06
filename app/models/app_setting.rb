class AppSetting < ApplicationRecord
  require "json"

  ENV_KEYS = {
    mailgun_domain: "MAILGUN_DOMAIN",
    mailgun_smtp_username: "MAILGUN_SMTP_USERNAME",
    mailgun_smtp_password: "MAILGUN_SMTP_PASSWORD",
    mailgun_smtp_address: "MAILGUN_SMTP_ADDRESS",
    mailgun_smtp_port: "MAILGUN_SMTP_PORT",
    mail_from_email: "MAIL_FROM_EMAIL",
    quote_receiver_email: "QUOTE_RECEIVER_EMAIL",
    app_host: "APP_HOST",
    app_port: "APP_PORT",
    app_protocol: "APP_PROTOCOL"
  }.freeze

  PUBLIC_FONT_OPTIONS = {
    "Fraunces (Serif)" => "fraunces",
    "Outfit (Sans)" => "outfit",
    "Plus Jakarta Sans (Sans)" => "plus_jakarta_sans",
    "Poppins (Sans)" => "poppins",
    "Montserrat (Sans)" => "montserrat",
    "Lato (Sans)" => "lato",
    "Nunito (Sans)" => "nunito",
    "Raleway (Sans)" => "raleway",
    "Playfair Display (Serif)" => "playfair_display",
    "Merriweather (Serif)" => "merriweather",
    "Roboto Slab (Serif)" => "roboto_slab",
    "Source Sans 3 (Sans)" => "source_sans_3",
    "Inter (Sans)" => "inter",
    "Roboto (Sans)" => "roboto",
    "Open Sans (Sans)" => "open_sans",
    "Manrope (Sans)" => "manrope",
    "DM Sans (Sans)" => "dm_sans",
    "Lora (Serif)" => "lora"
  }.freeze

  PUBLIC_FONT_STACKS = {
    "fraunces" => "\"Fraunces\", \"Times New Roman\", serif",
    "outfit" => "\"Outfit\", \"Trebuchet MS\", sans-serif",
    "plus_jakarta_sans" => "\"Plus Jakarta Sans\", \"Avenir Next\", \"Segoe UI\", sans-serif",
    "poppins" => "\"Poppins\", \"Segoe UI\", sans-serif",
    "montserrat" => "\"Montserrat\", \"Segoe UI\", sans-serif",
    "lato" => "\"Lato\", \"Segoe UI\", sans-serif",
    "nunito" => "\"Nunito\", \"Segoe UI\", sans-serif",
    "raleway" => "\"Raleway\", \"Segoe UI\", sans-serif",
    "playfair_display" => "\"Playfair Display\", \"Times New Roman\", serif",
    "merriweather" => "\"Merriweather\", \"Times New Roman\", serif",
    "roboto_slab" => "\"Roboto Slab\", \"Times New Roman\", serif",
    "source_sans_3" => "\"Source Sans 3\", \"Segoe UI\", sans-serif",
    "inter" => "\"Inter\", \"Segoe UI\", sans-serif",
    "roboto" => "\"Roboto\", \"Segoe UI\", sans-serif",
    "open_sans" => "\"Open Sans\", \"Segoe UI\", sans-serif",
    "manrope" => "\"Manrope\", \"Segoe UI\", sans-serif",
    "dm_sans" => "\"DM Sans\", \"Segoe UI\", sans-serif",
    "lora" => "\"Lora\", \"Times New Roman\", serif"
  }.freeze

  EDITOR_STYLE_KEYS = %w[
    font_size
    color
    font_weight
    font_style
    text_align
    text_transform
    letter_spacing
    line_height
    font_family
  ].freeze

  PARTNERS_TEXT_KEYS = %w[
    hero_title
    hero_lead
    partner_types_title
    split_title
    split_lead
  ].freeze
  PARTNERS_ARRAY_KEYS = %w[partner_types bullets].freeze
  PARTNERS_IMAGE_KEYS = %w[hero_image split_image].freeze

  HOME_TEXT_KEYS = %w[
    hero_title
    hero_lead
    why_title
    why_card_1_title
    why_card_1_body
    why_card_2_title
    why_card_2_body
    why_card_3_title
    why_card_3_body
    why_card_4_title
    why_card_4_body
    products_title
    product_1_title
    product_1_body
    product_2_title
    product_2_body
    product_3_title
    product_3_body
    product_4_title
    product_4_body
    contact_title
    contact_subtitle
    contact_intro_lead
    footer_tagline
  ].freeze
  HOME_ARRAY_KEYS = [].freeze
  HOME_IMAGE_KEYS = %w[
    hero_image
    why_card_1_image
    why_card_2_image
    why_card_3_image
    why_card_4_image
    product_1_image
    product_2_image
    product_3_image
    product_4_image
  ].freeze

  BUILDERS_TEXT_KEYS = %w[
    hero_title
    hero_lead
    why_title
    why_lead
    quote_title
    quote_lead
  ].freeze
  BUILDERS_ARRAY_KEYS = %w[why_bullets quote_bullets].freeze
  BUILDERS_IMAGE_KEYS = %w[hero_image split_image_one split_image_two].freeze

  EDITOR_PAGE_KEYS = %w[home partners builders].freeze

  DEFAULTS = {
    mailgun_domain: "email.tudouke.com",
    mailgun_smtp_username: "postmaster@email.tudouke.com",
    mailgun_smtp_password: "",
    mailgun_smtp_address: "smtp.mailgun.org",
    mailgun_smtp_port: 587,
    mail_from_email: "no-reply@email.tudouke.com",
    quote_receiver_email: "edward0127@hotmail.com",
    app_host: "localhost",
    app_port: 3000,
    app_protocol: "http",

    public_heading_font: "fraunces",
    public_body_font: "plus_jakarta_sans",
    public_cta_contact_label: "Get in touch",
    public_cta_login_label: "B2B Login",
    public_home_hero_image: "public-new-background-1.png",
    public_home_hero_title: "Your trade partner for exceptional interiors.",
    public_home_hero_lead: "Wholesale curtains, sheers and tracks for builders, developers and interior professionals.",
    public_home_why_title: "Simple, reliable supply for trade projects.",
    public_home_products_title: "Core range for trade projects",
    public_home_contact_title: "Get in Touch",
    public_home_contact_subtitle: "Planning a project?",
    public_footer_tagline: "Not just your ordinary curtain supplier.",
    public_partners_hero_image: "public-e-1.jpg",
    public_partners_hero_title: "Who we work with",
    public_partners_hero_lead: "Long-term trade partnerships built on reliability.",
    public_builders_hero_image: "public-e-40.jpg",
    public_builders_hero_title: "The finishing touch that completes every project",
    public_builders_hero_lead: "Trade-focused curtains and tracks for builders and developers."
  }.freeze

  validates :mailgun_smtp_port, numericality: { only_integer: true, greater_than: 0 }
  validates :app_port, numericality: { only_integer: true, greater_than: 0 }
  validates :mail_from_email, :quote_receiver_email, :mailgun_smtp_address, :mailgun_domain, :app_host, :app_protocol, presence: true
  validates :mailgun_smtp_username, presence: true
  validates :public_heading_font, inclusion: { in: PUBLIC_FONT_STACKS.keys }
  validates :public_body_font, inclusion: { in: PUBLIC_FONT_STACKS.keys }

  before_validation :apply_defaults

  def self.current
    first || create_with(default_attributes).create!
  end

  def self.fetch(key)
    setting = current
    value = setting.public_send(key)
    return value unless value.blank?

    fallback_for(key)
  end

  def self.smtp_settings
    return nil unless smtp_configured?

    {
      address: fetch(:mailgun_smtp_address),
      port: fetch(:mailgun_smtp_port).to_i,
      domain: fetch(:mailgun_domain),
      user_name: fetch(:mailgun_smtp_username),
      password: fetch(:mailgun_smtp_password),
      authentication: :plain,
      enable_starttls_auto: true
    }
  end

  def self.smtp_configured?
    fetch(:mailgun_smtp_username).present? && fetch(:mailgun_smtp_password).present?
  end

  def self.mailer_default_url_options
    {
      host: fetch(:app_host),
      port: fetch(:app_port).to_i,
      protocol: fetch(:app_protocol)
    }
  end

  def self.default_attributes
    DEFAULTS.each_with_object({}) do |(key, _), attrs|
      value = env_or_default(key)
      attrs[key.to_s] = [ :mailgun_smtp_port, :app_port ].include?(key) ? value.to_i : value
    end
  end

  def apply_defaults
    attrs = self.class.default_attributes

    self.class::DEFAULTS.each_key do |key|
      self[key] = attrs[key.to_s] if self[key].blank?
    end
  end

  def self.fallback_for(key)
    env_or_default(key)
  end

  def self.env_or_default(key)
    env_key = ENV_KEYS[key]
    default = DEFAULTS.fetch(key)
    return default if env_key.blank?

    ENV.fetch(env_key, default)
  end

  private_class_method :fallback_for, :env_or_default

  def page_content(page_key, preview: false)
    page = normalize_page_key(page_key)
    source = source_payload_for(page, preview: preview)
    normalize_page_payload(page, source)
  end

  def page_draft_content(page_key)
    page = normalize_page_key(page_key)
    draft_json = public_send("#{page}_page_draft_json")
    return nil if draft_json.blank?

    normalize_page_payload(page, parse_json_payload(draft_json))
  end

  def page_draft_present?(page_key)
    page = normalize_page_key(page_key)
    public_send("#{page}_page_draft_json").present?
  end

  def page_image_keys(page_key)
    case normalize_page_key(page_key)
    when "home" then HOME_IMAGE_KEYS
    when "partners" then PARTNERS_IMAGE_KEYS
    when "builders" then BUILDERS_IMAGE_KEYS
    else []
    end
  end

  def normalize_page_payload(page_key, payload)
    page = normalize_page_key(page_key)
    defaults = page_default_payload(page)

    normalize_payload(
      payload,
      defaults: defaults,
      text_keys: page_text_keys(page),
      array_keys: page_array_keys(page),
      image_keys: page_image_keys(page)
    )
  end

  def save_page_draft!(page_key, payload)
    page = normalize_page_key(page_key)
    normalized = normalize_page_payload(page, payload)
    update!("#{page}_page_draft_json" => normalized.to_json)
    normalized
  end

  def publish_page_draft!(page_key)
    page = normalize_page_key(page_key)
    draft_json = public_send("#{page}_page_draft_json")
    raise ArgumentError, "No saved draft available to publish." if draft_json.blank?

    published_before = page_content(page, preview: false)
    draft = normalize_page_payload(page, parse_json_payload(draft_json))

    attrs = {
      "#{page}_page_published_json" => draft.to_json,
      "#{page}_page_draft_json" => nil
    }
    attrs.merge!(published_columns_for(page, draft))

    update!(attrs)

    [ published_before, draft ]
  end

  def home_page_content(preview: false)
    page_content("home", preview: preview)
  end

  def home_page_draft_content
    page_draft_content("home")
  end

  def save_home_page_draft!(payload)
    save_page_draft!("home", payload)
  end

  def publish_home_page_draft!
    publish_page_draft!("home")
  end

  def normalize_home_payload(payload)
    normalize_page_payload("home", payload)
  end

  def partners_page_content(preview: false)
    page_content("partners", preview: preview)
  end

  def partners_page_draft_content
    page_draft_content("partners")
  end

  def save_partners_page_draft!(payload)
    save_page_draft!("partners", payload)
  end

  def publish_partners_page_draft!
    publish_page_draft!("partners")
  end

  def normalize_partners_payload(payload)
    normalize_page_payload("partners", payload)
  end

  def builders_page_content(preview: false)
    page_content("builders", preview: preview)
  end

  def builders_page_draft_content
    page_draft_content("builders")
  end

  def save_builders_page_draft!(payload)
    save_page_draft!("builders", payload)
  end

  def publish_builders_page_draft!
    publish_page_draft!("builders")
  end

  def normalize_builders_payload(payload)
    normalize_page_payload("builders", payload)
  end

  private

  def source_payload_for(page_key, preview:)
    draft_column = "#{page_key}_page_draft_json"
    published_column = "#{page_key}_page_published_json"

    raw = if preview && public_send(draft_column).present?
      public_send(draft_column)
    else
      public_send(published_column)
    end

    parse_json_payload(raw)
  end

  def normalize_page_key(page_key)
    key = page_key.to_s
    key = "partners" if key == "edit"
    raise ArgumentError, "Unsupported page key." unless EDITOR_PAGE_KEYS.include?(key)

    key
  end

  def page_default_payload(page_key)
    case page_key
    when "home" then home_page_default_payload
    when "partners" then partners_page_default_payload
    when "builders" then builders_page_default_payload
    else
      home_page_default_payload
    end
  end

  def page_text_keys(page_key)
    case page_key
    when "home" then HOME_TEXT_KEYS
    when "partners" then PARTNERS_TEXT_KEYS
    when "builders" then BUILDERS_TEXT_KEYS
    else []
    end
  end

  def page_array_keys(page_key)
    case page_key
    when "home" then HOME_ARRAY_KEYS
    when "partners" then PARTNERS_ARRAY_KEYS
    when "builders" then BUILDERS_ARRAY_KEYS
    else []
    end
  end

  def normalize_payload(payload, defaults:, text_keys:, array_keys:, image_keys:)
    source = payload.is_a?(Hash) ? payload : {}

    normalized = {
      "texts" => defaults["texts"].dup,
      "arrays" => defaults["arrays"].transform_values(&:dup),
      "images" => defaults["images"].dup,
      "styles" => {}
    }

    text_keys.each do |key|
      value = source.dig("texts", key)
      normalized["texts"][key] = value.to_s.strip.presence || defaults["texts"][key]
    end

    array_keys.each do |key|
      items = source.dig("arrays", key)
      list = Array(items).map { |item| item.to_s.strip }.reject(&:blank?)
      normalized["arrays"][key] = list.presence || defaults["arrays"][key]
    end

    image_keys.each do |key|
      value = source.dig("images", key).to_s.strip
      normalized["images"][key] = value.presence || defaults["images"][key]
    end

    styles = source.fetch("styles", {})
    if styles.is_a?(Hash)
      allowed_style_targets = text_keys + array_keys

      styles.each do |key, attrs|
        next unless allowed_style_targets.include?(key.to_s)
        next unless attrs.is_a?(Hash)

        style_hash = {}
        attrs.each do |style_key, style_value|
          next unless EDITOR_STYLE_KEYS.include?(style_key.to_s)

          clean = style_value.to_s.strip
          next if clean.blank?

          style_hash[style_key.to_s] = clean
        end
        normalized["styles"][key.to_s] = style_hash if style_hash.present?
      end
    end

    normalized
  end

  def published_columns_for(page_key, payload)
    case page_key
    when "home"
      {
        public_home_hero_image: payload.dig("images", "hero_image"),
        public_home_hero_title: payload.dig("texts", "hero_title"),
        public_home_hero_lead: payload.dig("texts", "hero_lead"),
        public_home_why_title: payload.dig("texts", "why_title"),
        public_home_products_title: payload.dig("texts", "products_title"),
        public_home_contact_title: payload.dig("texts", "contact_title"),
        public_home_contact_subtitle: payload.dig("texts", "contact_subtitle"),
        public_footer_tagline: payload.dig("texts", "footer_tagline")
      }
    when "partners"
      {
        public_partners_hero_image: payload.dig("images", "hero_image"),
        public_partners_hero_title: payload.dig("texts", "hero_title"),
        public_partners_hero_lead: payload.dig("texts", "hero_lead")
      }
    when "builders"
      {
        public_builders_hero_image: payload.dig("images", "hero_image"),
        public_builders_hero_title: payload.dig("texts", "hero_title"),
        public_builders_hero_lead: payload.dig("texts", "hero_lead")
      }
    else
      {}
    end
  end

  def home_page_default_payload
    {
      "texts" => {
        "hero_title" => public_home_hero_title.presence || self.class::DEFAULTS[:public_home_hero_title],
        "hero_lead" => public_home_hero_lead.presence || self.class::DEFAULTS[:public_home_hero_lead],
        "why_title" => public_home_why_title.presence || self.class::DEFAULTS[:public_home_why_title],
        "why_card_1_title" => "Trade-only supply",
        "why_card_1_body" => "For builders, developers, designers and local curtain businesses.",
        "why_card_2_title" => "Curated range",
        "why_card_2_body" => "A focused fabric range selected for repeatable results.",
        "why_card_3_title" => "Heat-set pleats",
        "why_card_3_body" => "Smooth, even folds that hold their shape over time.",
        "why_card_4_title" => "Practical support",
        "why_card_4_body" => "Lean service focused on what helps projects move.",
        "products_title" => public_home_products_title.presence || self.class::DEFAULTS[:public_home_products_title],
        "product_1_title" => "Curtain Tracks",
        "product_1_body" => "Cut-to-size tracks for smooth operation.",
        "product_2_title" => "S-Wave Curtains",
        "product_2_body" => "Clean, modern lines with consistent drape.",
        "product_3_title" => "Pinch Pleat Curtains",
        "product_3_body" => "Classic, tailored finish for premium interiors.",
        "product_4_title" => "Fabric Options",
        "product_4_body" => "Selected sheers and blockouts for dependable performance.",
        "contact_title" => public_home_contact_title.presence || self.class::DEFAULTS[:public_home_contact_title],
        "contact_subtitle" => public_home_contact_subtitle.presence || self.class::DEFAULTS[:public_home_contact_subtitle],
        "contact_intro_lead" => "Tell us what you need and our trade team will respond.",
        "footer_tagline" => public_footer_tagline.presence || self.class::DEFAULTS[:public_footer_tagline]
      },
      "arrays" => {},
      "images" => {
        "hero_image" => public_home_hero_image.presence || self.class::DEFAULTS[:public_home_hero_image],
        "why_card_1_image" => "public-e-14.jpg",
        "why_card_2_image" => "public-e-3.jpg",
        "why_card_3_image" => "public-e-37.jpg",
        "why_card_4_image" => "public-e-1.jpg",
        "product_1_image" => "public-e-12.jpg",
        "product_2_image" => "public-e-14.jpg",
        "product_3_image" => "public-e-40.jpg",
        "product_4_image" => "public-e-37.jpg"
      },
      "styles" => {}
    }
  end

  def partners_page_default_payload
    {
      "texts" => {
        "hero_title" => public_partners_hero_title.presence || self.class::DEFAULTS[:public_partners_hero_title],
        "hero_lead" => public_partners_hero_lead.presence || self.class::DEFAULTS[:public_partners_hero_lead],
        "partner_types_title" => "Who we work with across projects",
        "split_title" => "Built for repeat projects",
        "split_lead" => "Clear quoting, practical communication, and dependable delivery."
      },
      "arrays" => {
        "partner_types" => [
          "Developers",
          "Builders",
          "Architects",
          "Interior Designers",
          "Window Furnishing Businesses",
          "Real Estate Professionals"
        ],
        "bullets" => [
          "Clear updates from quote to install",
          "Consistent quality across projects",
          "Delivery you can plan around"
        ]
      },
      "images" => {
        "hero_image" => public_partners_hero_image.presence || self.class::DEFAULTS[:public_partners_hero_image],
        "split_image" => "public-e-12.jpg"
      },
      "styles" => {}
    }
  end

  def builders_page_default_payload
    {
      "texts" => {
        "hero_title" => public_builders_hero_title.presence || self.class::DEFAULTS[:public_builders_hero_title],
        "hero_lead" => public_builders_hero_lead.presence || self.class::DEFAULTS[:public_builders_hero_lead],
        "why_title" => "Curtains shape how finished homes feel",
        "why_lead" => "Well-fitted sheers and blockouts add warmth, improve presentation, and complete the space.",
        "quote_title" => "Ready to quote your next development?",
        "quote_lead" => "Fast pricing, practical communication, and reliable delivery."
      },
      "arrays" => {
        "why_bullets" => [
          "Better presentation at handover",
          "Stronger buyer appeal",
          "Ready-to-live-in feel"
        ],
        "quote_bullets" => [
          "True wholesale pricing",
          "Quick turnaround",
          "Tailored service to your project specs"
        ]
      },
      "images" => {
        "hero_image" => public_builders_hero_image.presence || self.class::DEFAULTS[:public_builders_hero_image],
        "split_image_one" => "public-e-3.jpg",
        "split_image_two" => "public-e-37.jpg"
      },
      "styles" => {}
    }
  end

  def parse_json_payload(raw)
    parsed = JSON.parse(raw.to_s)
    parsed.is_a?(Hash) ? parsed : {}
  rescue JSON::ParserError
    {}
  end
end
