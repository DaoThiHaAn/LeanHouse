class Floor < ApplicationRecord
  belongs_to :house, inverse_of: :floors, counter_cache: true
  has_many :rooms, inverse_of: :floor, dependent: :destroy

  before_validation :normalize_name

  validates :name, :rooms_count, presence: true
  validates :rooms_count, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 50 }
  # Floors within a house must be unique
  validates :name, uniqueness: {
    scope: :house_id,
    case_sensitive: false
  }

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

  def normalize_name
    self.name = name&.squish
  end

  def generate_rooms_in_room_mode!(count:, max_slots: 1, rent: 0, deposit: 0, area: 1)
    transaction do
      count.times do |i|
        room = rooms.create!(
          name: (i + 1).to_s,
          max_slots: max_slots,
          tenants_count: 0,
          area: area
        )

        room.create_rental_unit!(
          rent: rent,
          deposit: deposit
        )
      end
    end
  end
end
