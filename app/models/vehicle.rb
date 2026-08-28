class Vehicle < ApplicationRecord
  belongs_to :tenant, inverse_of: :vehicles
  belongs_to :house, inverse_of: :vehicles

  has_one_attached :vehicle_photo # Retained for garage security

  validates :license_plate, presence: true, uniqueness: { scope: :house_id }

  enum :vehicle_type, {
    motorbike: "motorbike",
    electric_bike: "electric_bike",
    bicycle: "bicycle",
    car: "car"
  }, default: :motorbike

  scope :sorted, -> { order(created_at: :desc) }
  scope :by_type, ->(type) { where(vehicle_type: type) if type.present? }
  scope :search, ->(query) do
    return all if query.blank?
    q = "%#{sanitize_sql_like(query.strip)}%"
    joins(tenant: :user).where(
      "unaccent(vehicles.license_plate) ILIKE unaccent(:q)
       OR unaccent(vehicles.brand) ILIKE unaccent(:q)
       OR unaccent(vehicles.model) ILIKE unaccent(:q)
       OR unaccent(users.fullname) ILIKE unaccent(:q)",
      q: q
    )
  end

  def human_type
    I18n.t("enums.vehicle.vehicle_type.#{vehicle_type}", default: vehicle_type.humanize)
  end

  def type_icon
    case vehicle_type
    when "motorbike" then "two_wheeler"
    when "electric_bike" then "electric_scooter"
    when "bicycle" then "pedal_bike"
    when "car" then "directions_car"
    else "directions_car"
    end
  end
end
