class RentalUnit < ApplicationRecord
  # look at "rentable_type" to determine whether the rentable is a Room or a Bed
  belongs_to :rentable, polymorphic: true
  has_many :tenant_stays, inverse_of: :rental_unit, dependent: :destroy

  enum :status, { active: "active", deleted: "deleted" }

  validates :rent, :deposit, presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 1000000000 }
  validates :status, inclusion: { in: statuses.keys }
end
