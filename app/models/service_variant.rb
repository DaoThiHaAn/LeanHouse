class ServiceVariant < ApplicationRecord
  belongs_to :service, inverse_of: :service_variants, touch: true
  has_one :house, through: :service
  has_many :room_services, inverse_of: :service_variant, dependent: :destroy
  has_many :rooms, through: :room_services, inverse_of: :service_variants

  enum :unit, {
    per_person: "person",
    per_room: "room",
    per_month: "month",
    per_item: "item",
    per_hour: "hour",
    per_use: "use",
    per_kwh: "kWh",
    per_m3: "m3"
  }

  validates :fee, :unit, presence: true
  validates :fee, numericality: { only_integer: true, greater_than: 0 }
  validates :unit, presence: true, inclusion: { in: units.keys }


  # Used in views to display the unit options in a select dropdown
  def self.unit_options
    units.keys.map do |unit|
      [
        I18n.t("enums.room_service.unit.#{unit}"),
        unit
      ]
    end
  end

  def human_unit
    I18n.t("enums.room_service.unit.#{unit}", default: unit.to_s)
  end

  # SQL-optimized: fetches all rooms in the house eligible for this variant,
  # excluding rooms assigned to sibling variants of the same service.
  def eligible_rooms
    other_assigned_room_ids = RoomService
      .joins(:service_variant)
      .where(service_variants: { service_id: service_id })
      .where.not(service_variant_id: id)
      .select(:room_id)

    house.rooms.active.where.not(id: other_assigned_room_ids).includes(:floor).sorted
  end

  # SQL-optimized: bulk syncs room assignments via single delete_all and insert_all queries
  # Returns array of affected room IDs
  def sync_room_assignments(submitted_room_ids)
    allowed_ids = eligible_rooms.pluck(:id).to_set
    target_ids = Array(submitted_room_ids).map(&:to_i).select { |rid| allowed_ids.include?(rid) }.uniq

    current_ids = room_services.pluck(:room_id)
    to_add = target_ids - current_ids
    to_remove = current_ids - target_ids

    RoomService.transaction do
      room_services.where(room_id: to_remove).delete_all if to_remove.any?
      if to_add.any?
        now = Time.current
        records = to_add.map do |rid|
          { room_id: rid, service_variant_id: id, created_at: now, updated_at: now }
        end
        RoomService.insert_all(records)
      end
      touch
    end

    to_add + to_remove
  end

  # SQL-optimized: fetches active tenant users in affected rooms
  def active_staying_tenant_users(target_room_ids = nil)
    r_ids = target_room_ids || rooms.pluck(:id)
    return User.none if r_ids.empty?

    User.joins(tenant: { tenant_stays: :rental_unit })
        .where(tenant_stays: { checkout_at: nil })
        .where(
          "(rental_units.rentable_type = 'Room' AND rental_units.rentable_id IN (:r_ids)) OR " \
          "(rental_units.rentable_type = 'Bed' AND rental_units.rentable_id IN " \
          "(SELECT beds.id FROM beds WHERE beds.room_id IN (:r_ids) AND beds.deleted = false))",
          r_ids: r_ids
        ).distinct
  end

  private
end
