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


  private
end
