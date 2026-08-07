class Room < ApplicationRecord
  belongs_to :floor, inverse_of: :rooms, counter_cache: :rooms_count, touch: true
  has_one :house, through: :floor
  has_one :rental_unit, as: :rentable, dependent: :destroy
  has_many :beds, inverse_of: :room, dependent: :destroy
  has_many :room_services, inverse_of: :room, dependent: :destroy
  has_many :services, through: :room_services, inverse_of: :rooms

  validates :name, :max_slots, :tenants_count, :area, presence: true
  validates :name, uniqueness: {
    scope: :floor_id,
    case_sensitive: false
  }
  validates :max_slots, numericality: {
    only_integer: true,
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: 20
  }
  validates :tenants_count, numericality: {
    only_integer: true,
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: :max_slots
  }
  validates :area, numericality: {
    greater_than_or_equal_to: 1,
    less_than_or_equal_to: 500
  }

  default_scope { where(deleted: false) }
  scope :deleted, -> { where(deleted: true) }
  # Rooms are grouped by floor in ascending position order, and then by name in ascending order
  scope :sorted, -> {
    joins(:floor).order("floors.position ASC, rooms.name ASC")
  }

  scope :available, -> { where("tenants_count < max_slots") }
  scope :full,      -> { where("tenants_count = max_slots") }

  # Model method

  def available?
    tenants_count < max_slots
  end

  def empty?
    tenants_count.zero?
  end

  def create_beds(count:, rent: 0, deposit: 0)
    transaction do
      count.times do |i|
        bed = beds.create!(
          name: (i + 1).to_s,
        )

        bed.create_rental_unit!(
          rent: rent,
          deposit: deposit
        )
      end

      touch
    end
  end
end
