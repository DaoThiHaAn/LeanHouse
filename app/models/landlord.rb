class Landlord < ApplicationRecord
  self.primary_key = :id
  belongs_to :user, foreign_key: :id, primary_key: :id, inverse_of: :landlord
  has_many :houses, dependent: :destroy, inverse_of: :landlord
end
