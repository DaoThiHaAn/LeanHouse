class BedCreationForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  MAX_SLOTS = 20

  attribute :beds_count, :integer
  attribute :floor_id, :integer
  attribute :room_id, :integer
  attr_accessor :room

  validates :beds_count, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :floor_id, :room_id, presence: true
  validate :room_matches_selected_floor
  validate :beds_count_within_room_limit

  def room
    @room ||= Room.find_by(id: room_id) if room_id.present?
  end

  private

  def room_matches_selected_floor
    return if floor_id.blank? || room_id.blank?

    selected_room = Room.find_by(id: room_id)
    return if selected_room.blank?
    return if selected_room.floor_id.to_i == floor_id.to_i

    errors.add(:room_id, :invalid)
  end

  def beds_count_within_room_limit
    return if beds_count.blank? || !beds_count.is_a?(Numeric)
    return if room.blank?

    available_slots = [ MAX_SLOTS - room.max_slots.to_i, 0 ].max
    return if beds_count <= available_slots

    errors.add(:beds_count, :exceeds_max_slots, count: available_slots)
  end
end
