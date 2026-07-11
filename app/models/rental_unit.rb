class RentableUnit < ApplicationRecord
  # look at "rentable_type" to determine whether the rentable is a Room or a Bed
  belongs_to :rentable, polymorphic: true

  enum status: { active: "active", deleted: "deleted" }

  validates :rent, :deposit, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :status, presence: true, inclusion: { in: statuses.keys }
end
