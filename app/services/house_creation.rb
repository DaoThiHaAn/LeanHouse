# Create a House based on the HouseCreationForm form model

class HouseCreation
  SERVICES = {
    elec: "service.elec_money",
    water: "service.water_money",
    wifi: "service.wifi_money",
    parking: "service.parking_money"
  }.freeze


  def initialize(landlord:, form:)
    @landlord = landlord # the current landlord creating the house
    @form = form
  end

  def call
    ActiveRecord::Base.transaction do
      house = create_house

      # create floors, rooms, beds, and services based on the created house
      create_rental_units(house)
      create_services(house)

      house
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

  def build_floor_names
    floor_names = []
    total_floors = form.floors_count.to_i

    if form.has_ground_floor == "1"
      floor_names << "Trệt"
      total_floors -= 1
    end

    total_floors.times do |i|
      floor_names << "#{i + 1}"
    end

    floor_names
  end

  def create_rental_units(house)
    floor_names =  build_floor_names
    mode = house.bed? ? :bed : :room

    # create floors -> auto update floors_count in house
    floor_names.each do |name|
      floor =  house.floors.create!(
        name: name,
        rooms_count: 0
      )
      floor.generate_rooms!(
        mode: mode,
        count: form.rooms_per_floor.to_i,
        max_slots: form.capacity.to_i,
        rent: form.rent,
        deposit: form.deposit,
        area: form.area.to_f
      )
    end
  end

  def create_services(house)
    # Services for the whole house and are applied for all rooms

    # House services
    variants = []

    SERVICES.each do |key, translation|
      next unless form.public_send("#{key}_money") == "1"

      parent_service = house.services.create!(
        name: I18n.t(translation)
      )

      variant = parent_service.service_variants.create!(
        fee: form.public_send("#{key}_price"),
        unit: form.public_send("#{key}_unit"),
        is_real_time: form.public_send("#{key}_real_time"))

      variants << variant
    end

    return if variants.empty?

    # Room services
    now = Time.current

    rows = house.rooms.flat_map do |room|
            variants.map do |variant| {
              room_id: room.id,
              service_variant_id: variant.id,
              created_at: now,
              updated_at: now }
            end
          end

    RoomService.insert_all!(rows) # execute all SQL at once
  end
end
