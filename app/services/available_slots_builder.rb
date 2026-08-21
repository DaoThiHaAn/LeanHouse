# Prepare available slots for a tenant to move in
class AvailableSlotsBuilder
  Result = Data.define(:floors, :rooms, :rental_units, :room_options, :bed_options)

  def self.call(...)
    new(...).call
  end

  def initialize(house:, excluded_rental_unit_id: nil)
    @house = house
    @excluded_rental_unit_id = excluded_rental_unit_id
  end

  def call
    rental_units = fetch_rental_units
    rooms = rental_units.filter_map(&:room).uniq
    floors = rooms.filter_map(&:floor).uniq.sort_by(&:position)

    Result.new(
      floors: floors,
      rooms: rooms,
      rental_units: rental_units,
      room_options: build_room_options(rental_units, rooms),
      bed_options: build_bed_options(rental_units)
    )
  end

  private

  attr_reader :house, :excluded_rental_unit_id

  def fetch_rental_units
    units = house.available_rental_units.to_a
    units.reject! { |u| u.id == excluded_rental_unit_id } if excluded_rental_unit_id
    units
  end

  def build_room_options(rental_units, rooms)
    if house.room?
      rental_units.map do |unit|
        room = unit.rentable
        { id: room.id, floorId: room.floor_id, name: room.name, rentalUnitId: unit.id }
      end
    else
      rooms.map do |room|
        { id: room.id, floorId: room.floor_id, name: room.name, rentalUnitId: nil }
      end
    end
  end

  def build_bed_options(rental_units)
    return [] unless house.bed?

    rental_units.map do |unit|
      bed = unit.rentable
      { id: bed.id, roomId: bed.room_id, name: bed.name, rentalUnitId: unit.id }
    end
  end
end
