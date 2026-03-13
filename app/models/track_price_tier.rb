class TrackPriceTier < ApplicationRecord
  validates :track_name, :currency, presence: true
  validates :width_band_min_mm, :width_band_max_mm, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :price, numericality: { greater_than_or_equal_to: 0 }
end
