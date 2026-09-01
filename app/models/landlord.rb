class Landlord < ApplicationRecord
  self.primary_key = :id
  belongs_to :user, foreign_key: :id, primary_key: :id, inverse_of: :landlord
  has_many :houses, dependent: :destroy, inverse_of: :landlord
  has_many :contracts, dependent: :destroy
  has_many :requests, through: :houses
  has_many :bank_accounts, dependent: :destroy

  validates :houses_count, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 20 }

  # METHODS

  # Return whole other houses except the current house_id
  def get_other_houses(house_id)
    houses.where.not(id: house_id)
  end
end
