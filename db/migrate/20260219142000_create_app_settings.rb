class CreateAppSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :app_settings do |t|
      t.string :mailgun_domain
      t.string :mailgun_smtp_username
      t.string :mailgun_smtp_password
      t.string :mailgun_smtp_address
      t.integer :mailgun_smtp_port
      t.string :mail_from_email
      t.string :quote_receiver_email
      t.string :app_host
      t.integer :app_port
      t.string :app_protocol

      t.timestamps
    end
  end
end
