class PublicContactForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :first_name, :string
  attribute :last_name, :string
  attribute :email, :string
  attribute :company, :string
  attribute :message, :string
  attribute :subscribe_updates, :boolean, default: false

  validates :first_name, :last_name, :email, :company, :message, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :message, length: { maximum: 3000 }

  def full_name
    [ first_name, last_name ].join(" ").strip
  end
end
