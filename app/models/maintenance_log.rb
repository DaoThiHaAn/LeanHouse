class MaintenanceLog < ApplicationRecord
  belongs_to :asset, inverse_of: :maintenance_logs
  has_one :room, through: :asset
  has_one :house, through: :room

  validates :performed_on, presence: true
  validates :cost, presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 1_000_000_000 }
  validates :content, presence: true, length: { maximum: 200 }

  before_validation :normalize_strings

  default_scope -> { order(performed_on: :asc) }

  private

  def normalize_strings
    self.content = content&.squish
  end
end
