# frozen_string_literal: true

class HouseModeChanger
  def initialize(house)
    @house = house
  end

  def call
    return false unless @house.can_change_mode?

    ActiveRecord::Base.transaction do
      if @house.room?
        convert_to_bed_mode
      else
        convert_to_room_mode
      end

      @house.touch
      LandlordDashboardBroadcaster.broadcast_later(@house.id)
      true
    end
  end

  private

  attr_reader :house

  def convert_to_bed_mode
    house.rooms.includes(:rental_unit, :beds).find_each do |room|
      bed_count = [ room.max_slots, 1 ].max
      old_unit = room.rental_unit
      rent_per_bed = old_unit ? (old_unit.rent.to_i / bed_count) : 0
      deposit_per_bed = old_unit ? (old_unit.deposit.to_i / bed_count) : 0

      # Remove room-level rental unit
      old_unit&.destroy!

      # Reset max_slots to 0 before creating beds because Bed counter-caches :max_slots
      room.update_columns(max_slots: 0)

      # Create beds with individual rental units
      room.create_beds(
        count: bed_count,
        rent: rent_per_bed,
        deposit: deposit_per_bed
      )
    end

    house.update!(mode: :bed)
  end

  def convert_to_room_mode
    house.rooms.includes(:rental_unit, beds: :rental_unit).find_each do |room|
      active_beds = room.beds.active.to_a
      bed_count = [ active_beds.size, room.max_slots, 1 ].max

      total_rent = active_beds.sum { |b| b.rental_unit&.rent.to_i }
      total_deposit = active_beds.sum { |b| b.rental_unit&.deposit.to_i }

      # Destroy all beds (dependent: :destroy removes polymorphic rental_units)
      room.beds.destroy_all

      # Create or update room-level rental unit
      if room.rental_unit.present?
        room.rental_unit.update!(rent: total_rent, deposit: total_deposit)
      else
        room.create_rental_unit!(rent: total_rent, deposit: total_deposit)
      end

      # Restore max_slots to bed count
      room.update_columns(max_slots: bed_count)
    end

    house.update!(mode: :room)
  end
end
