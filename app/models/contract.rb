class Contract < ApplicationRecord
  has_one :tenant, dependent: :destroy
  has_one :house, dependent: :destroy
  has_one :landlord, dependent: :destroy

  validates :citizen_id, :start_date, :due_date, presence: true
  validates :due_date, comparison: { greater_than: :start_date }
end
