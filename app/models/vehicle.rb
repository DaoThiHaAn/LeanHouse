class Vehicle < ApplicationRecord
  belongs_to :tenant
  belongs_to :house

  has_one_attached :vehicle_photo # Retained for garage security

  validates :license_plate, presence: true, uniqueness: { scope: :house_id }

  enum :vehicle_type, {
    motorbike: "motorbike",
    electric_bike: "electric_bike",
    bicycle: "bicycle",
    car: "car"
  }, default: :motorbike
end
