class Bed < ApplicationRecord
  belongs_to :room, inverse_of: :beds, counter_cache: :max_slots, touch: true
  has_one :rental_unit, as: :rentable, dependent: :destroy
  has_one :house, through: :room

  validates :name, presence: true

  scope :active, -> { where(deleted: false) }
  scope :deleted, -> { where(deleted: true) }
  scope :sorted, -> { order(name: :asc) }

  # MODEL METHODS

  def available?
    is_available
  end

  def available__for?(rental_unit)
    is_available
  end
end
