class QuoteRequest < ApplicationRecord
  belongs_to :user

  enum :status, { submitted: 0, reviewed: 1 }

  validates :width, numericality: { greater_than: 0 }
  validates :height, numericality: { greater_than: 0 }
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :notes, length: { maximum: 2000 }
end
