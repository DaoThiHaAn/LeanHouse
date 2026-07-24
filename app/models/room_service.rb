class RoomService < ApplicationRecord
  self.primary_key = [ :service_id, :room_id ]

  belongs_to :room, inverse_of: :room_services
  belongs_to :service, inverse_of: :room_services
  has_one :house, through: :room

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
  validate :room_and_service_must_belong_to_same_house


  def self.unit_options
    # Used in views to display the unit options in a select dropdown
    units.keys.map do |unit|
      [
        I18n.t("enums.room_service.unit.#{unit}"),
        unit
      ]
    end
  end


  private

  def room_and_service_must_belong_to_same_house
    cur_room = self.room
    cur_service = self.service
    return unless cur_room && cur_service  # return when either room or service is nil

    house_id_of_room = cur_room.floor&.house_id # in validation case, can't
    house_id_of_service = cur_service.house_id

    if house_id_of_room != house_id_of_service
      errors.add(:base, :different_house)
    end
  end
end
