class QuoteRequest < ApplicationRecord
  belongs_to :user
  belongs_to :created_by_user, class_name: "User", optional: true
  has_many :quote_items, -> { order(:line_position, :id) }, dependent: :destroy

  accepts_nested_attributes_for :quote_items, allow_destroy: true, reject_if: :quote_item_blank?

  enum :status, {
    submitted: 0,
    reviewed: 1,
    priced: 2,
    sent_to_customer: 3,
    approved: 4,
    rejected: 5,
    converted_to_job: 6,
    order_processing: 7,
    ready_for_pick_up: 8,
    completed: 9,
    cancelled: 10
  }

  enum :customer_mode, {
    b2b: 0,
    b2c: 1
  }

  enum :pickup_method, {
    delivery: 0,
    pickup: 1
  }

  STATUS_DISPLAY_NAMES = {
    "submitted" => "Submitted",
    "reviewed" => "Reviewed",
    "priced" => "Priced",
    "sent_to_customer" => "Sent To Customer",
    "approved" => "Approved",
    "rejected" => "Rejected",
    "converted_to_job" => "Converted To Job",
    "order_processing" => "Order Processing",
    "ready_for_pick_up" => "Ready For Pick Up",
    "completed" => "Completed",
    "cancelled" => "Cancelled"
  }.freeze

  ORDER_WORKFLOW_STATUSES = %w[
    order_processing
    ready_for_pick_up
    completed
    cancelled
  ].freeze

  STATUS_TRANSITIONS = {
    "submitted" => %w[reviewed priced rejected order_processing],
    "reviewed" => %w[priced rejected order_processing],
    "priced" => %w[sent_to_customer rejected order_processing],
    "sent_to_customer" => %w[approved rejected order_processing],
    "approved" => %w[order_processing],
    "rejected" => [],
    "converted_to_job" => [],
    "order_processing" => %w[ready_for_pick_up completed cancelled],
    "ready_for_pick_up" => %w[completed cancelled],
    "completed" => [],
    "cancelled" => []
  }.freeze

  validates :quote_number, presence: true, uniqueness: true
  validates :currency, presence: true
  validates :notes, length: { maximum: 2000 }
  validates :company_name, presence: true, if: :b2c?
  validate :requires_at_least_one_quote_item

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

  def update_order_status!(target_status)
    target = target_status.to_s
    unless ORDER_WORKFLOW_STATUSES.include?(target)
      raise ArgumentError, "Invalid order status: #{target_status}"
    end

    self.status = target
    mark_status_timestamp(target)
    save!
  end

  def line_items_count
    quote_items.size
  end

  def display_status
    self.class.status_label_for(status)
  end

  def order_workflow?
    ORDER_WORKFLOW_STATUSES.include?(status)
  end

  def show_track_details?
    quote_items.any?(&:show_track_details?)
  end

  alias_method :legacy_track_details?, :show_track_details?

  def active_curtain_only_pricing?
    quote_items.any? && quote_items.all?(&:active_curtain_only_pricing?)
  end

  def legacy_document_labels?
    show_track_details? || quote_items.any?(&:pinch_pleat_style?)
  end

  def style_heading_label
    legacy_document_labels? ? "Style (S Wave / Pinch Pleat)" : "Style"
  end

  def factory_style_heading_label(multiline: false)
    legacy_label = multiline ? "Style\n(\u6b3e\u5f0f)\n\u86c7\u5f62/\u97e9\u54f2" : "Style (\u6b3e\u5f0f) \u86c7\u5f62/\u97e9\u54f2"
    active_label = multiline ? "Style\n(\u6b3e\u5f0f)\n\u86c7\u5f62" : "Style (\u6b3e\u5f0f) \u86c7\u5f62"

    legacy_document_labels? ? legacy_label : active_label
  end

  def opening_count_heading_label
    legacy_document_labels? ? "OW (1) or C/O (2)" : "Openings (1 / 2)"
  end

  def track_group_heading
    "Tracks" if show_track_details?
  end

  def track_length_heading_label
    show_track_details? ? "Length" : nil
  end

  def opening_code_heading_label
    legacy_document_labels? ? "OW or C/O" : "Opening Code"
  end

  def factory_details_section_title
    show_track_details? ? "Track details (TO LOCAL FACTORY)" : "Installation / accessory details (TO LOCAL FACTORY)"
  end

  def self.status_label_for(status_key)
    key = status_key.to_s
    return "Unknown" if key.blank?

    STATUS_DISPLAY_NAMES.fetch(key, key.humanize)
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
    when "order_processing"
      self.submitted_at ||= timestamp
    when "ready_for_pick_up"
      self.ready_for_pick_up_at ||= timestamp
    when "completed"
      self.completed_at ||= timestamp
    when "cancelled"
      self.cancelled_at ||= timestamp
    end
  end
end
