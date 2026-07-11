class Floor < ApplicationRecord
  belongs_to :house, inverse_of: :floors, counter_cache: true
  has_many :rooms, inverse_of: :floor, dependent: :destroy

  validates :name, :rooms_count, presence: true
  validates :rooms_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
