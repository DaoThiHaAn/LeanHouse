# Updates the records that collectively define a room. Keeping this in one
# transaction prevents a room, its rental units, and its service selections
# from getting out of sync when any part of the edit is invalid.
class RoomUpdate
  def initialize(room:, house:, room_attributes:, rental_attributes:, service_selections:)
    @room = room
    @house = house
    @room_attributes = room_attributes.to_h.symbolize_keys
    @rental_attributes = rental_attributes.to_h.symbolize_keys
    @service_selections = service_selections || {}
  end

  def call
    assign_form_values
    return false unless valid?

    ActiveRecord::Base.transaction do
      room.save!
      room.update_column(:max_slots, requested_max_slots) if house.room?
      update_rental_units!
      sync_services!
    end

    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  private

  attr_reader :room, :house, :room_attributes, :rental_attributes, :service_selections

  def assign_form_values
    # Bed mode derives capacity from the bed counter cache, so only beds may
    # change max_slots there.
    attributes = house.bed? ? room_attributes.except(:max_slots) : room_attributes
    room.assign_attributes(attributes)
    room.service_selections = service_selections
    cleaned_rental = rental_attributes.merge(
      rent: parse_currency(rental_attributes[:rent]),
      deposit: parse_currency(rental_attributes[:deposit])
    )
    room.rent = cleaned_rental[:rent]
    room.deposit = cleaned_rental[:deposit]

    rental_units.each { |unit| unit.assign_attributes(cleaned_rental) }
  end

  def parse_currency(value)
    return value if value.is_a?(Numeric)
    return nil if value.blank?

    value.to_s.gsub(/[^\d]/, "").to_i
  end

  def valid?
    room.valid?(:service_selection)
    requested_capacity_is_valid
    capacity_not_less_than_staying_tenants
    valid_rental_units
    selected_variants_belong_to_house
    room.errors.empty?
  end

  def capacity_not_less_than_staying_tenants
    return if house.bed?

    if requested_max_slots < room.tenants_count
      room.errors.add(
        :max_slots,
        I18n.t("errors.capacity_below_tenants", count: room.tenants_count, default: "Không thể giảm sức chứa xuống dưới số khách hiện tại (#{room.tenants_count} người)!")
      )
    end
  end

  def requested_capacity_is_valid
    return if house.bed?
    return if room_attributes[:max_slots].to_s.match?(/\A\d+\z/) &&
              requested_max_slots.between?(1, 20)

    room.errors.add(:max_slots, :invalid)
  end

  def valid_rental_units
    rental_units.each do |unit|
      next if unit.valid?

      unit.errors.each do |error|
        room.errors.add(error.attribute, error.message)
      end
    end
  end

  def selected_variants_belong_to_house
    return if selected_variant_ids.all? { |id| available_service_variants.key?(id) }

    room.errors.add(:base, "contains an invalid service variant")
  end

  def requested_max_slots
    room_attributes.fetch(:max_slots, previous_max_slots).to_i
  end

  def previous_max_slots
    @previous_max_slots ||= room.max_slots
  end

  def rental_units
    @rental_units ||= if house.bed?
      room.beds.active.includes(:rental_unit).filter_map(&:rental_unit)
    else
      [ room.rental_unit ].compact
    end
  end

  def selected_variant_ids
    @selected_variant_ids ||= service_selections.to_h.filter_map do |_service_id, selection|
      selection["variant_id"].to_i if selection["selected"].to_s == "1"
    end
  end

  def available_service_variants
    @available_service_variants ||= house.service_variants
      .where(id: selected_variant_ids)
      .index_by(&:id)
  end

  def update_rental_units!
    rental_units.each(&:save!)
  end

  def sync_services!
    selected_variant_ids.each do |variant_id|
      room.room_services.find_or_create_by!(
        service_variant: available_service_variants.fetch(variant_id)
      )
    end
    room.room_services.where.not(service_variant_id: selected_variant_ids).destroy_all
  end
end
