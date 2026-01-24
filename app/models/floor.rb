class Floor < ApplicationRecord
  belongs_to :house, inverse_of: :floors
  
  validates :name, presence: true
end
