class Landlord < ApplicationRecord
  self.primary_key = :id
  belongs_to :user, foreign_key: :id
end
