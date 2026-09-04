module Invoices
  class OccupiedRoomsQuery
    attr_reader :house

    def self.call(house)
      new(house).call
    end

    def initialize(house)
      @house = house
    end

    def call
      occupied_rooms = house.rooms.active.occupied.sorted.includes(
        :floor,
        :rental_unit,
        beds: { rental_unit: { tenant_stays: { tenant: :user } } },
        tenant_stays: { tenant: :user }
      )

      floor_ids = occupied_rooms.map(&:floor_id).uniq
      floors = house.floors.where(id: floor_ids).order(:position)

      rooms_data = occupied_rooms.map do |room|
        tenants_list = if house.bed?
          room.all_staying_bed_tenants.map do |item|
            {
              id: item[:tenant].id,
              name: "#{item[:tenant].user.fullname} (#{I18n.t('invoice.bed', default: 'Giường')} #{item[:bed].name})"
            }
          end
        else
          room.all_staying_tenants.map do |t|
            {
              id: t.id,
              name: t.user.fullname
            }
          end
        end

        {
          id: room.id,
          name: room.title_name,
          floor_id: room.floor_id,
          floor_name: room.floor.title_name,
          tenants_count: room.tenants_count,
          tenants: tenants_list
        }
      end

      {
        occupied_rooms: occupied_rooms,
        floors: floors,
        rooms_data: rooms_data
      }
    end
  end
end
