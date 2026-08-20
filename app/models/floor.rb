class Floor < ApplicationRecord
  belongs_to :house, inverse_of: :floors, counter_cache: true, touch: true
  has_many :rooms, inverse_of: :floor, dependent: :destroy

  before_validation :normalize_name
  before_validation :assign_position, on: :create

  attr_accessor :room_area,
                :room_rent,
                :room_capacity,
                :room_deposit

  validates :name, :rooms_count, presence: true
  validates :rooms_count, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 50 }
  # Floors within a house must be unique
  validates :name, uniqueness: {
    scope: :house_id,
    case_sensitive: false
  }

  scope :pos_order, -> { order(:position) }
  scope :available, -> { where("rooms_count < ?", 100) } # A floor can add new rooms

  # MODEL METHODS

  # Format the name in format: "Floor ..."
  def title_name
    I18n.t("form.floor.self") + " " + name
  end

  def reach_max_rooms?
    rooms_count.to_i == 100
  end

  # Get maximum available slots of each floor
  def total_slots
    rooms.sum(:max_slots)
  end

  def can_delete?
    # All rooms must be empty
    !rooms.where("tenants_count > 0").exists?
  end

  # @param mode [[:room, :bed]] house mode
  def generate_rooms!(
    mode:, count:,
    max_slots: 1, rent: 0, deposit: 0, area: 1)
    room_max_slots = mode == :room ? max_slots : 0

    transaction do
      count.times do |i|
        room = rooms.create!(
          name: (i + 1).to_s,
          max_slots: room_max_slots,
          tenants_count: 0,
          area: area
        )

        case mode
        when :room
          room.create_rental_unit!(
            rent: rent, deposit: deposit
          )

        when :bed
          room.create_beds(
            count: max_slots, rent: rent, deposit: deposit
          )
        end
      end

      house.touch
    end
  end


  private

  def normalize_name
    self.name = name&.squish
  end

  def assign_position
    return if position.present?

    # In manual creation, the position is at the highest order
    self.position = house.floors_count + 1
  end
end
