class House < ApplicationRecord
  has_one_attached :regulation_file
  belongs_to :landlord, inverse_of: :houses, counter_cache: :houses_count
  has_many :floors, inverse_of: :house, dependent: :destroy
  has_many :rooms, through: :floors, dependent: :destroy
  has_many :beds, through: :rooms, dependent: :destroy
  has_many :services, inverse_of: :house, dependent: :destroy
  has_many :service_variants, through: :services
  has_many :assets, through: :rooms

  # Rails auto generates helper methods for enum values
  enum :mode, { room: "room", bed: "bed" }

  validates :name, :mode, :address_l1, :address_l2, :address_l3, :floors_count, presence: true
  validates :floors_count, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 50 }
  validate :validate_regulation_file
  validates :mode, inclusion: { in: modes.keys }
  validates :inv_creation_date, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 31 }

  scope :active, -> { where(is_deleted: false) }
  scope :deleted, -> { where(is_deleted: true) }
  scope :sorted, -> { order(name: :asc) }

  scope :search, ->(query) do
    return all if query.blank?
    query = "%#{sanitize_sql_like(query)}%"

    where(
        "unaccent(name) ILIKE unaccent(:query)
        OR unaccent(address_l1) ILIKE unaccent(:query)
        OR unaccent(address_l2) ILIKE unaccent(:query)
        OR unaccent(address_l3) ILIKE unaccent(:query)",
        query: query
      )
  end

  # MODEL METHODS

  def reach_max_floors?
    floors_count.to_i == 50
  end

  def occupancy_rate
    slots = total_slots

    return 0 if slots.zero?
    ((occupied_slots.to_f / slots) * 100).round(2)
  end

  def total_slots
    rooms.sum(:max_slots)
  end

  def occupied_slots
    rooms.sum(:tenants_count)
  end

  def total_rooms
    floors.sum(:rooms_count)
  end

  # Soft delete the house
  def deleted
  end

  def can_delete?
    !rooms.where("tenants_count > 0").exists?
  end


  # Returns active, available rental units with their location preloaded.
  # @return [Array<RentalUnit>]
  def available_rental_units
    if room?
      RentalUnit
        .where(rentable_type: "Room")
        .joins("INNER JOIN rooms ON rooms.id = rental_units.rentable_id")
        .joins("INNER JOIN floors ON floors.id = rooms.floor_id")
        .where(
          floors: { house_id: id },
          rooms: { deleted: false }
        )
        .where("rooms.tenants_count < rooms.max_slots")
        .includes(rentable: :floor)
        .order("floors.position ASC, rooms.name ASC")
    else
      RentalUnit
        .where(rentable_type: "Bed")
        .joins("INNER JOIN beds ON beds.id = rental_units.rentable_id")
        .joins("INNER JOIN rooms ON rooms.id = beds.room_id")
        .joins("INNER JOIN floors ON floors.id = rooms.floor_id")
        .where(
          floors: { house_id: id },
          rooms: { deleted: false },
          beds: { deleted: false, is_available: true }
        )
        .includes(rentable: { room: :floor })
        .order("floors.position ASC, rooms.name ASC, beds.name ASC")
    end
  end

  # Return all linked tenants with/without signing contracts
  # @param signed_contract [Boolean]
  # @return tenants [Array<Tenant>]
  def all_linked_tenants(signed_contract:)
    rentable_records = room? ? rooms : beds
    rental_units = RentalUnit.where(rentable: rentable_records)

    Tenant
      .includes(:user, :contracts)
      .joins(:tenant_stays)
      .where(tenant_stays: {
        rental_unit_id: rental_units,
        checkout_at: nil,
        has_contract: signed_contract
      })
      .name_sorted
      .distinct
  end

  private

  def validate_regulation_file
    return unless regulation_file.attached?

    unless regulation_file.content_type == "application/pdf"
      errors.add(
        :regulation_file, :invalid_file)
    end

    if regulation_file.byte_size > 50.megabytes
      errors.add(:regulation_file, :too_large)
    end
  end
end
