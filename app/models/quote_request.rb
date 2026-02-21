class QuoteRequest < ApplicationRecord
  belongs_to :user
  belongs_to :quote_template
  has_many :quote_items, -> { order(:line_position, :id) }, dependent: :destroy
  has_one :job, dependent: :destroy

  accepts_nested_attributes_for :quote_items, allow_destroy: true, reject_if: :quote_item_blank?

  enum :status, {
    submitted: 0,
    reviewed: 1,
    priced: 2,
    sent_to_customer: 3,
    approved: 4,
    rejected: 5,
    converted_to_job: 6
  }

  STATUS_TRANSITIONS = {
    "submitted" => %w[reviewed priced rejected],
    "reviewed" => %w[priced rejected],
    "priced" => %w[sent_to_customer rejected],
    "sent_to_customer" => %w[approved rejected],
    "approved" => %w[converted_to_job],
    "rejected" => [],
    "converted_to_job" => []
  }.freeze

  validates :quote_number, presence: true, uniqueness: true
  validates :currency, presence: true
  validates :notes, length: { maximum: 2000 }
  validate :requires_at_least_one_quote_item

  before_validation :assign_default_quote_template
  before_validation :assign_quote_number, on: :create
  before_validation :assign_default_valid_until
  before_validation :sync_legacy_fields_from_primary_item
  before_save :recalculate_totals

  scope :recent_first, -> { order(created_at: :desc) }

  def can_transition_to?(target_status)
    allowed_targets = STATUS_TRANSITIONS.fetch(status, [])
    allowed_targets.include?(target_status.to_s)
  end

  def transition_to!(target_status)
    target = target_status.to_s
    raise ArgumentError, "Invalid quote status: #{target_status}" unless self.class.statuses.key?(target)
    raise ArgumentError, "Cannot transition from #{status} to #{target}" unless can_transition_to?(target)

    self.status = target
    mark_status_timestamp(target)
    save!
  end

  def convert_to_job!(notes: nil)
    raise ArgumentError, "Quote must be approved before job conversion." unless approved?
    return job if job.present?

    transaction do
      created_job = create_job!(
        user: user,
        notes: notes
      )
      self.status = :converted_to_job
      self.converted_to_job_at = Time.current
      save!
      created_job
    end
  end

  def line_items_count
    quote_items.size
  end

  private

  def quote_item_blank?(attributes)
    attributes["product_id"].blank? &&
      attributes["width"].blank? &&
      attributes["height"].blank? &&
      attributes["description"].blank?
  end

  def requires_at_least_one_quote_item
    active_items = quote_items.reject(&:marked_for_destruction?)
    errors.add(:base, "At least one quote line item is required.") if active_items.empty?
  end

  def assign_default_quote_template
    self.quote_template ||= QuoteTemplate.default_template
  end

  def assign_quote_number
    return if quote_number.present?

    loop do
      candidate = format("Q-%<date>s-%<suffix>05d", date: Date.current.strftime("%Y%m%d"), suffix: SecureRandom.random_number(100_000))
      unless self.class.exists?(quote_number: candidate)
        self.quote_number = candidate
        break
      end
    end
  end

  def assign_default_valid_until
    self.valid_until ||= 14.days.from_now.to_date
  end

  def sync_legacy_fields_from_primary_item
    item = quote_items.reject(&:marked_for_destruction?).first
    return unless item

    self.width = item.width.presence || width.presence || 1
    self.height = item.height.presence || height.presence || 1
    self.quantity = [ item.quantity.to_i, 1 ].max
  end

  def recalculate_totals
    active_items = quote_items.reject(&:marked_for_destruction?)
    self.subtotal = active_items.sum { |item| item.line_total.to_d }.round(2)
    self.total = subtotal
  end

  def mark_status_timestamp(target)
    timestamp = Time.current

    case target
    when "reviewed"
      self.reviewed_at ||= timestamp
    when "priced"
      self.priced_at ||= timestamp
    when "sent_to_customer"
      self.sent_at ||= timestamp
    when "approved"
      self.approved_at ||= timestamp
    when "rejected"
      self.rejected_at ||= timestamp
    when "converted_to_job"
      self.converted_to_job_at ||= timestamp
    end
  end
end
