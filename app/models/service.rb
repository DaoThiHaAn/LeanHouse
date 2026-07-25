class Service < ApplicationRecord
  before_validation :normalize_name

  belongs_to :house, inverse_of: :services
  has_many :room_services, inverse_of: :service, dependent: :destroy
  has_many :rooms, through: :room_services, inverse_of: :services

  validates :name, presence: true,
            uniqueness: {
              scope: :house_id,
              case_sensitive: false
            }


  # Get all variant of a service applied in different rooms
  # Return "pluck"
  def all_variants
    room_services.distinct.pluck(:fee, :unit, :is_real_time)
  end

  private

  def normalize_name
    self.name = name&.squish
  end
end
