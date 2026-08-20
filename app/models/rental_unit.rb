class RentalUnit < ApplicationRecord
  # look at "rentable_type" to determine whether the rentable is a Room or a Bed
  # .rentabl returns the corresponding object
  belongs_to :rentable, polymorphic: true
  has_many :tenant_stays, inverse_of: :rental_unit, dependent: :destroy

  validates :rent, :deposit, presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 1000000000 }

  # MODEL METHODS

  # Check a bed or a room is available for rent
  def available?
    rentable.available?
  end

  # Update the state and the tenants_count in Room
  def tenant_added!
    rentable.tenant_added!
  end

  # A tenant is unlinked
  def tenant_removed!
    rentable.tenant_removed!
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

  # Format the name of the rental unit in format:
  # "Bed ..." or "Room ..."
  # @return [string] the name of a Room or a Bed
  def title_name
    rentable.title_name
  end

  # Get the full location information  of a rental unit
  # @return [string] in format: "Bed ..., Room ..., Floor ..."
  def location_info
    parts = []
    parts << title_name if bed
    parts << room&.title_name
    parts << floor&.title_name
    parts.compact_blank.join(", ")
  end
end
