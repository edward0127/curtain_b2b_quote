class QuoteTemplate < ApplicationRecord
  has_many :quote_requests, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: true
  validates :heading, presence: true
  validate :single_default_template

  before_validation :normalize_name
  after_commit :ensure_default_template_exists, on: %i[ create update destroy ]

  scope :alphabetical, -> { order(:name) }

  def self.default_template
    find_by(default_template: true) || first
  end

  private

  def normalize_name
    self.name = name.to_s.parameterize if name.present?
  end

  def single_default_template
    return unless default_template?

    existing_default = self.class.where(default_template: true).where.not(id: id).exists?
    errors.add(:default_template, "is already assigned to another template") if existing_default
  end

  def ensure_default_template_exists
    return if self.class.where(default_template: true).exists?

    candidate = self.class.order(:id).first
    candidate&.update_column(:default_template, true)
  end
end
