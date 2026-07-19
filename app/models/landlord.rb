class Landlord < ApplicationRecord
  self.primary_key = :id
  belongs_to :user, foreign_key: :id, primary_key: :id, inverse_of: :landlord
  has_many :houses, dependent: :destroy, inverse_of: :landlord

  validates :houses_count, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 20 }
end
