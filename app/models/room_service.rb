class RoomService < ApplicationRecord
  belongs_to :room, inverse_of: :room_services, touch: true
  belongs_to :service_variant, inverse_of: :room_services, touch: true
  has_one :house, through: :room
  has_one :service, through: :service_variant

  validates :room_id, uniqueness: { scope: :service_variant_id, message: :already_applied }

  validate :room_and_service_variant_must_belong_to_same_house

  private

  def room_and_service_variant_must_belong_to_same_house
    return unless room && service_variant

    room_house_id = room.floor&.house_id
    service_house_id = service_variant.service&.house_id

    return if room_house_id.nil? || service_house_id.nil?
    return if room_house_id == service_house_id

    errors.add(:base, :different_house)
  end
end
