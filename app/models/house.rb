class House < ApplicationRecord
  # fields that are not stored in the database, but are used for form submission and validation
  # attr_accessor :rooms_per_floor, :area, :rent, :capacity, :deposit, :has_ground_floor,
  #               :services, :elec, :elec_price, :elec_unit, :elec_real_time, :water, :wifi, :parking

  has_one_attached :regulation_file
  belongs_to :landlord, inverse_of: :houses, counter_cache: :houses_count
  has_many :floors, inverse_of: :house, dependent: :destroy
  has_many :rooms, through: :floors, dependent: :destroy
  has_many :beds, through: :rooms, dependent: :destroy
  has_many :room_services, through: :rooms, dependent: :destroy
  has_many :services, inverse_of: :house, dependent: :destroy

  # Rails auto generates helper methods for enum values
  enum :mode, { room: "room", bed: "bed" }

  validates :name, :mode, :address_l1, :address_l2, :address_l3, :floors_count, presence: true
  validates :floors_count, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 50 }
  validate :validate_regulation_file
  validates :mode, inclusion: { in: modes.keys }
  validates :inv_creation_date, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 31 }

  scope :active, -> { where(is_deleted: false) }
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

  def deleted
    # Soft delete the house
  end

  private

  def validate_regulation_file
    return unless regulation_file.attached?

    unless regulation_file.content_type == "application/pdf"
      errors.add(:regulation_file, "must be a PDF")
    end

    if regulation_file.byte_size > 50.megabytes
      errors.add(:regulation_file, "must be smaller than 5 MB")
    end
  end
end
