class House < ApplicationRecord
  # fields that are not stored in the database, but are used for form submission and validation
  attr_accessor :rooms_per_floor, :area, :rent, :capacity, :deposit, :has_ground_floor,
                :services, :elec, :elec_price, :elec_unit, :elec_real_time, :water, :wifi, :parking

  has_one_attached :regulation_file
  belongs_to :landlord, inverse_of: :houses
  has_many :floors, inverse_of: :house, dependent: :destroy
  has_many :rooms, through: :floors, inverse_of: :house, dependent: :destroy
  has_many :beds, through: :rooms, inverse_of: :house, dependent: :destroy
  has_many :room_services, through: :rooms, inverse_of: :house, dependent: :destroy
  has_many :services, inverse_of: :house, dependent: :destroy

  # Rails auto generates helper methods for enum values
  enum mode: { room: "room", bed: "bed" }

  validates :name, :mode, :rooms_per_floor, :address_l1, :address_l2, :address_l3, :floors_count, presence: true
  validates :floors_count, numericality: { only_integer: true, greater_than: 0 }
  validate :validate_regulation_file
  validates :mode, inclusion: { in: modes.keys }
  validates :inv_creation_date, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 31 }

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
