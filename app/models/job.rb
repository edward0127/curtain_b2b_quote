class Job < ApplicationRecord
  belongs_to :quote_request
  belongs_to :user

  enum :status, { open: 0, in_progress: 1, completed: 2 }

  validates :job_number, presence: true, uniqueness: true

  before_validation :assign_job_number, on: :create

  scope :recent_first, -> { order(created_at: :desc) }

  private

  def assign_job_number
    return if job_number.present?

    loop do
      candidate = format("JOB-%<date>s-%<suffix>05d", date: Date.current.strftime("%Y%m%d"), suffix: SecureRandom.random_number(100_000))
      unless self.class.exists?(job_number: candidate)
        self.job_number = candidate
        break
      end
    end
  end
end
