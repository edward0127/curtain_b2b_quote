class PricebookImport < ApplicationRecord
  belongs_to :imported_by_user, class_name: "User"

  enum :status, {
    pending: 0,
    running: 1,
    succeeded: 2,
    failed: 3
  }

  validates :import_type, :source_filename, presence: true

  scope :recent_first, -> { order(created_at: :desc) }

  def start!
    update!(status: :running, started_at: Time.current, finished_at: nil, error_message: nil)
  end

  def succeed!(products_updated_count:, price_matrix_entries_count:, track_price_tiers_count:, log_output:)
    update!(
      status: :succeeded,
      finished_at: Time.current,
      products_updated_count: products_updated_count,
      price_matrix_entries_count: price_matrix_entries_count,
      track_price_tiers_count: track_price_tiers_count,
      log_output: log_output.to_s
    )
  end

  def fail!(error_message:, log_output:)
    update!(
      status: :failed,
      finished_at: Time.current,
      error_message: error_message.to_s,
      log_output: log_output.to_s
    )
  end
end
