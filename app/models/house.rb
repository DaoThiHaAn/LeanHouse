class House < ApplicationRecord
  has_one_attached :regulation_file
  belongs_to :landlord, inverse_of: :houses, counter_cache: :houses_count
  has_many :floors, inverse_of: :house, dependent: :destroy
  has_many :rooms, through: :floors, dependent: :destroy
  has_many :beds, through: :rooms, dependent: :destroy
  has_many :services, inverse_of: :house, dependent: :destroy
  has_many :service_variants, through: :services
  has_many :assets, through: :rooms
  has_many :contracts,  inverse_of: :house, dependent: :destroy
  has_many :requests,   inverse_of: :house, dependent: :destroy
  has_many :vehicles,   inverse_of: :house, dependent: :destroy
  has_many :invoices,   inverse_of: :house, dependent: :destroy
  has_many :service_usage_logs, through: :rooms

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
  scope :by_mode, ->(mode) { where(mode: mode) if modes.key?(mode) }

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

  scope :by_state, ->(state) do
    return all if state.blank?

    case state
    when "available"
      where(
        id: Room.where(deleted: false)
                .joins(:floor)
                .group("floors.house_id")
                .having("SUM(rooms.max_slots) > SUM(rooms.tenants_count)")
                .select("floors.house_id")
      )
    when "full"
      where(
        id: Room.where(deleted: false)
                .joins(:floor)
                .group("floors.house_id")
                .having("SUM(rooms.max_slots) > 0 AND SUM(rooms.max_slots) <= SUM(rooms.tenants_count)")
                .select("floors.house_id")
      )
    when "not_empty", "occupied"
      where(
        id: Room.where(deleted: false)
                .joins(:floor)
                .group("floors.house_id")
                .having("SUM(rooms.tenants_count) > 0")
                .select("floors.house_id")
      )
    when "empty"
      where.not(
        id: Room.where(deleted: false)
                .joins(:floor)
                .where("rooms.tenants_count > 0")
                .select("floors.house_id")
      )
    when "room"
      where(mode: :room)
    when "bed"
      where(mode: :bed)
    else
      all
    end
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

  def full_address
    [ address_l3, address_l2, address_l1 ].compact_blank.join(", ")
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

  def tenant_summary_stats
    signed = all_linked_tenants(signed_contract: true).size
    unsigned = all_linked_tenants(signed_contract: false).size
    total_occupied = signed + unsigned
    total = total_slots
    vacant = [ total - total_occupied, 0 ].max
    pending_requests = requests.where(status: :pending).count

    {
      total_tenants: total_occupied,
      signed_count: signed,
      unsigned_count: unsigned,
      vacant_slots: vacant,
      pending_requests_count: pending_requests
    }
  end

  # @param tenant_id [int]
  # @return [TenantStay]: the object that show a tenant is actually living in the house
  def tenant_stay_for(tenant_id)
    rental_units = RentalUnit.where(
      rentable: room? ? rooms : beds
    )

    TenantStay
      .staying
      .find_by(rental_unit_id: rental_units, tenant_id: tenant_id)
  end

  # @return [Array<Contract>] all contracts of the current staying tenants
  def all_current_contracts
    rentable_records = room? ? rooms : beds
    rental_units = RentalUnit.where(rentable: rentable_records)
    contracts
      .includes(tenant: :user)
      .joins(tenant: :tenant_stays)
      .where(tenant_stays: {
        rental_unit_id: rental_units,
        checkout_at: nil
      })
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
