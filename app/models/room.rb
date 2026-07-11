class Room < ApplicationRecord
  belongs_to :floor, inverse_of: :rooms, counter_cache: :rooms_count
  has_one :rentable_unit, as: :rentable, dependent: :destroy
  has_many :beds, inverse_of: :room, dependent: :destroy
  has_many :room_services, inverse_of: :room, dependent: :destroy
  has_many :services, through: :room_services, inverse_of: :rooms

  validates :name, :max_slots, :tenants_count, :area, :rent, presence: true
  validates :max_slots, :rent, numericality: {
    only_integer: true,
    greater_than_or_equal_to: 1,
    less_than_or_equal_to: 30
  }
  validates :tenants_count, numericality: {
    only_integer: true,
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: :max_slots
  }

  # Model method

  def available?
    tenants_count < max_slots
  end

  def empty?
    tenants_count.zero?
  end
end
