class HouseCreationForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  # override the model name
  def self.model_name
    ActiveModel::Name.new(self, nil, "House")
  end

  attr_accessor :landlord

  # House
  attribute :name
  attribute :mode
  attribute :address_l1
  attribute :address_l2
  attribute :address_l3
  attribute :has_ground_floor
  attribute :floors_count
  attribute :inv_creation_date
  attribute :regulation_file

  # Floor template
  attribute :rooms_per_floor

  # Room template
  attribute :area
  attribute :rent
  attribute :capacity
  attribute :deposit

  # Service config
  attribute :elec_money
  attribute :elec_price
  attribute :elec_unit
  attribute :elec_real_time
  attribute :water_money
  attribute :water_price
  attribute :water_unit
  attribute :water_real_time
  attribute :wifi_money
  attribute :wifi_price
  attribute :wifi_unit
  attribute :wifi_real_time, :boolean, default: false # not rendered in view
  attribute :parking_money
  attribute :parking_price
  attribute :parking_unit
  attribute :parking_real_time, :boolean, default: false # not rendered in view

  validates :rooms_per_floor,
            numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 50 }
  validates :elec_price,
            numericality: { only_integer: true, greater_than: 0 }, if: -> { elec_money == "1" }
  validates :water_price,
            numericality: { only_integer: true, greater_than: 0 }, if: -> { water_money == "1" }
  validates :wifi_price,
            numericality: { only_integer: true, greater_than: 0 }, if: -> { wifi_money == "1" }
  validates :parking_price,
            numericality: { only_integer: true, greater_than: 0 }, if: -> { parking_money == "1" }

  validate :validate_house_model_constraints

  private

  # Reuse the validations of House
  def validate_house_model_constraints
    house = House.new(
      landlord: landlord,
      name: name,
      mode: mode,
      address_l1: address_l1,
      address_l2: address_l2,
      address_l3: address_l3,
      floors_count: floors_count,
      inv_creation_date: inv_creation_date,
      regulation_file: regulation_file
    )

    unless house.valid?
      # Copy errors of House to Form object
      house.errors.each do |error|
        self.errors.add(error.attribute, error.message)
      end
    end
  end
end
