class Bed < ApplicationRecord
  belongs_to :room, inverse_of: :beds, counter_cache: :max_slots
  has_one :rentable_unit, as: :rentable, dependent: :destroy
  has_one :house, through: :room

  validates :name, presence: true

  default_scope { where(deleted: false) }
  scope :deleted, -> { where(deleted: true) }
  scope :sorted, -> { order(name: :asc) }

  # MODEL METHODS

  def available?
    is_available
  end
end
