class Floor < ApplicationRecord
  belongs_to :house, inverse_of: :floors, counter_cache: true
  has_many :rooms, inverse_of: :floor, dependent: :destroy

  validates :name, :rooms_count, presence: true
  validates :rooms_count, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 50 }
  default_scope { order(:position) }

  # MODEL METHODS

  def reach_max_rooms?
    rooms_count.to_i == 100
  end

  # Get maximum available slots of each floor
  def total_slots
    rooms.sum(:max_slots)
  end

  def can_delete?
    # All rooms must be empty
    !rooms.where("tenants_count > 0").exists?
  end
end
