# Create a House based on the HouseCreationForm form model

class HouseCreation
  SERVICES = [
    { key: :elec,    translation: "service.elec_money" },
    { key: :water,   translation: "service.water_money" },
    { key: :wifi,    translation: "service.wifi_money" },
    { key: :parking, translation: "service.parking_money" }
  ].freeze


  def initialize(landlord:, form:)
    @landlord = landlord # the current landlord creating the house
    @form = form
  end

  def call
    ActiveRecord::Base.transaction do
      house = create_house
      bed_mode = house.bed?

      # create floors, rooms, beds, and services based on the created house
      floors = create_floors(house)
      rooms = create_rooms(floors, bed_mode)
      if bed_mode
        create_beds(rooms)
      end
      create_services(house, rooms)

      return house
    end
  end

  private

  attr_reader :landlord, :form

  def create_house
    house = landlord.houses.create!(
      name: form.name,
      mode: form.mode,
      address_l1: form.address_l1,
      address_l2: form.address_l2,
      address_l3: form.address_l3,
      inv_creation_date: form.inv_creation_date,
      floors_count: 0
    )

    house.regulation_file.attach(form.regulation_file) if form.regulation_file.present?
    house
  end

  def create_floors(house)
    floor_name = []
    total_floors = form.floors_count.to_i

    # build floor name array
    if form.has_ground_floor == "1"
      floor_name << "Trệt"
      total_floors -= 1
    end

    total_floors.times do |i|
      floor_name << "#{i + 1}"
    end

    # create floors -> auto update floors_count in house
    floors = []
    floor_name.each do |name|
      floors << house.floors.create!(
        name: name,
        rooms_count: 0
      )
    end

    floors
  end

  def create_rooms(floors, bed_mode)
    rooms = []
    max_slots = bed_mode ? 0 : form.capacity.to_i # creating beds auto update the counter cache

    floors.each do |floor|
      # Each floor has the same number of rooms
      form.rooms_per_floor.to_i.times do |i|
        new_room = floor.rooms.create!(
          name: "#{i + 1}",
          max_slots: max_slots,
          tenants_count: 0,
          area: form.area.to_f
        )

        unless bed_mode
          create_rental_unit(new_room)
        end

        rooms << new_room
      end
    end

    rooms
  end

  def create_beds(rooms)
    max_slots = form.capacity.to_i

    rooms.each do |room|
      max_slots.times do |i|
        bed = room.beds.create!( # auto update tenants_count in room
          name: "#{i + 1}",
          is_available: true
        )

        create_rental_unit(bed)
      end
    end
  end

  def create_services(house, rooms)
    # Services for the whole house and are applied for all rooms

    # House services
    house_services = {}
    SERVICES.each do |service|
      next unless form.public_send("#{service[:key]}_money") == "1"

      house_services[service[:key]] = house.services.create!(
        name: I18n.t(service[:translation])
      )
    end

    # Room services
    rooms.each do |room|
      SERVICES.each do |service|
        key = service[:key]
        next unless form.public_send("#{key}_money").present?

        # Look up the parent service created in step 1
        parent_service = house_services[key]
        next unless parent_service.present?

        room.room_services.create!(
          service: parent_service,
          fee: form.public_send("#{key}_price"),
          unit: form.public_send("#{key}_unit"),
          is_real_time: form.public_send("#{key}_real_time").presence
        )
      end
    end
  end

  def create_rental_unit(rentable_object)
    RentalUnit.create!(
      rentable: rentable_object, # Rails automatically extracts rentable_type & rentable_id
      rent: form.rent,
      deposit: form.deposit
    )
  end
end
