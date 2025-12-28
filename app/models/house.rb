class House < ApplicationRecord
  attr_accessor :rooms_per_floor, :area, :rent, :capacity, :deposit
  has_one_attached :regulation_file

  belongs_to :landlord, inverse_of: :houses

  validates :name, :mode, :rooms_per_floor, :address_l1, :address_l2, :address_l3, :floors_count, :rooms_count, presence: true
  validates :rooms_count, :floors_count, comparison: { greater_than: 0 }
  validates :mode, inclusion: { in: %w[room dorm] }
end
