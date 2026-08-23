class Room < ApplicationRecord
  attr_accessor :service_selections, :rent, :deposit

  belongs_to :floor, inverse_of: :rooms, counter_cache: :rooms_count, touch: true
  has_one :house, through: :floor
  has_one :rental_unit, as: :rentable, dependent: :destroy
  has_many :beds, inverse_of: :room, dependent: :destroy
  has_many :tenant_stays, through: :rental_unit
  has_many :tenants, through: :tenant_stays
  has_many :bed_rental_units, through: :beds, source: :rental_unit
  has_many :room_services, inverse_of: :room, dependent: :destroy
  has_many :service_variants, through: :room_services, inverse_of: :rooms
  has_many :services, through: :service_variants, inverse_of: :rooms
  has_many :assets, dependent: :destroy

  before_validation :normalize_name

  validates :name, :max_slots, :tenants_count, :area, presence: true
  validates :name, uniqueness: {
    scope: :floor_id,
    case_sensitive: false
  }
  validates :max_slots, numericality: {
    only_integer: true,
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: 20
  }
  validates :tenants_count, numericality: {
    only_integer: true,
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: :max_slots
  }
  validates :area, numericality: {
    greater_than_or_equal_to: 1,
    less_than_or_equal_to: 500
  }
  validate :selected_services_have_variants, on: :service_selection

  scope :active, -> { where(deleted: false) }
  scope :deleted, -> { where(deleted: true) }
  # Rooms are grouped by floor in ascending position order, and then by name in ascending order
  scope :sorted, -> {
    joins(:floor).order("floors.position ASC, rooms.name ASC")
  }

  scope :available, -> { where("tenants_count < max_slots") }
  scope :full,      -> { where("tenants_count = max_slots") }

  # Model method

  def title_name
    I18n.t("form.room.self") + " " + self.name
  end

  # Can be rented
  def available?
    !deleteted && tenants_count < max_slots
  end

  def empty?
    tenants_count.zero?
  end

  def create_beds(count:, rent: 0, deposit: 0, start_at: 0)
    transaction do
      count.times do |i|
        bed = beds.create!(
          name: (start_at + i + 1).to_s,
        )

        bed.create_rental_unit!(
          rent: rent,
          deposit: deposit
        )
      end

      touch
    end
  end

  # A tenant is linked to a room
  def tenant_added!
    increment!(:tenants_count)
  end

  # A tenant is unlinked to a room
  def tenant_removed!
    decrement!(:tenants_count)
  end

  # @param house [House] the house object
  # @param selections [Hash<Hash>] the list of selected services
  # @option selections [Hash] :service_id The ID of the service as a string key
  #   * :selected [String] "1" or "0" indicating if selected
  #   * :variant_id [String] The ID of the specific variant
  def add_services(house:, selections:)
    # Get only selected selections from form
    selected_selections =
      selections.select do |_service_id, selection|
        selection["selected"].to_s == "1"
      end

    return if selected_selections.empty?

    # All selected variant_ids of selected services
    variant_ids =
      selected_selections.values.map do |selection|
        selection["variant_id"]
      end

    variants = house.service_variants
                    .where(id: variant_ids)
                    .index_by { |variant| variant.id.to_s } # make a hash

    selected_selections.each do |_service_id, selection|
      room_services.create!(
        service_variant: variants.fetch(selection["variant_id"].to_s)
      )
    end

    touch
  end

  # Return all tenants currently staying in a room
  # @return [Array<Tenant>]
  def all_staying_tenants
    tenant_stays.staying.includes(tenant: :user).map(&:tenant)
  end


  # Tenants renting individual beds in the room
  # @return [{tenant: ..., bed: ...}, ...]
  def all_staying_bed_tenants
    beds.includes(
      rental_unit: { tenant_stays: { tenant: :user } }
    ).flat_map do |bed|
      bed.rental_unit.tenant_stays.staying.map do |stay|
        {
          tenant: stay.tenant,
          bed: bed
        }
      end
    end
  end


  # Unify the data structure to use in view
  # @param house [House]: the current house
  # @param stayer_id [int]
  def formatted_roommates(house, stayer_id)
    if house.bed?
      beds.includes(
        rental_unit: { tenant_stays: { tenant: :user } }
      ).flat_map do |bed|
        bed.rental_unit.tenant_stays.staying
          .where.not(tenant_id: stayer_id)
          .map { |stay| {
            user: stay.tenant.user,
            bed_name: bed.name }
          }
      end

    else
      tenant_stays.staying
        .where.not(tenant_id: stayer_id)
        .includes(tenant: :user)
        .map { |stay| {
          user: stay.tenant.user,
          bed_name: nil }
        }
    end
  end


  private

  def real_max_slots
    house_context.room? ? max_slots : 0
  end

  def selected_services_have_variants
    return if service_selections.blank?

    service_selections.each do |service_id, selection|
      next unless selection["selected"].to_s == "1"

      if selection["variant_id"].blank?
        errors.add(:"service_#{service_id}", I18n.t("errors.service_variant_required"))
      end
    end
  end

  def normalize_name
    self.name = name&.squish
  end
end
