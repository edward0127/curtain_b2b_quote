admin_email = ENV.fetch("SEED_ADMIN_EMAIL", "admin@example.com")
admin_password = ENV.fetch("SEED_ADMIN_PASSWORD", "ChangeMe123!")

User.find_or_initialize_by(email: admin_email).tap do |admin|
  admin.role = :admin
  admin.password = admin_password
  admin.password_confirmation = admin_password
  admin.save!
end

AppSetting.current
