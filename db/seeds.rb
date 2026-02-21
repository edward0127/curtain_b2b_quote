admin_email = ENV.fetch("SEED_ADMIN_EMAIL", "admin@example.com")
admin_password = ENV.fetch("SEED_ADMIN_PASSWORD", "ChangeMe123!")

User.find_or_initialize_by(email: admin_email).tap do |admin|
  admin.role = :admin
  admin.password = admin_password
  admin.password_confirmation = admin_password
  admin.save!
end

AppSetting.current

standard_template = QuoteTemplate.find_or_initialize_by(name: "standard")
standard_template.assign_attributes(
  heading: "Curtain Quote",
  intro: "Thank you for your enquiry. This quote includes all requested lines.",
  terms: "Quote valid for 14 days. Final measurements are subject to site confirmation.",
  footer: "Please contact our team to accept this quote.",
  default_template: true
)
standard_template.save!

QuoteTemplate.where.not(id: standard_template.id).update_all(default_template: false)

[
  {
    name: "Sheer Curtain Panel",
    sku: "SHEER-001",
    description: "Sheer fabric panel priced per square meter.",
    base_price: 42.50,
    pricing_mode: :per_square_meter,
    active: true
  },
  {
    name: "Blackout Curtain Panel",
    sku: "BLACKOUT-001",
    description: "Blockout panel priced per square meter.",
    base_price: 68.00,
    pricing_mode: :per_square_meter,
    active: true
  },
  {
    name: "Track Installation",
    sku: "INSTALL-TRACK",
    description: "Installation service priced per unit.",
    base_price: 120.00,
    pricing_mode: :per_unit,
    active: true
  }
].each do |attrs|
  product = Product.find_or_initialize_by(sku: attrs.fetch(:sku))
  product.assign_attributes(attrs)
  product.save!
end
