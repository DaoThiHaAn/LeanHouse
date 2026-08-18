class RentalUnit < ApplicationRecord
  # look at "rentable_type" to determine whether the rentable is a Room or a Bed
  belongs_to :rentable, polymorphic: true
  has_many :tenant_stays, inverse_of: :rental_unit, dependent: :destroy

  validates :rent, :deposit, presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 1000000000 }

  # MODEL METHODS

  # Check a bed or a room is available for rent
  def available?
    rentable.active? && rentable.available?
  end

  def bed
    rentable if rentable_type == "Bed"
  end

  def room
    rentable.is_a?(Room) ? rentable : rentable&.room
  end

  def floor
    room&.floor
  end

  def house
    room&.house
  end
end
