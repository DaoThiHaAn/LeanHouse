class Service < ApplicationRecord
  before_validation :normalize_name

  belongs_to :house, inverse_of: :services, touch: true
  has_many :service_variants, dependent: :destroy, inverse_of: :service
  has_many :room_services, through: :service_variants, dependent: :destroy
  has_many :rooms, through: :room_services

  validates :name, presence: true,
            uniqueness: {
              scope: :house_id,
              case_sensitive: false
            }

  private

  def normalize_name
    self.name = name&.squish
  end
end
