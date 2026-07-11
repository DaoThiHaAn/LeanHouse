class Service < ApplicationRecord
  belongs_to :house, inverse_of: :services
  has_many :room_services, inverse_of: :service, dependent: :destroy
  has_many :rooms, through: :room_services, inverse_of: :services

  validates :name, presence: true
end
