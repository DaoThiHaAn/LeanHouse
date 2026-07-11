class Bed < ApplicationRecord
  belongs_to :room, inverse_of: :beds, counter_cache: :max_slots
  has_one :rentable_unit, as: :rentable, dependent: :destroy

  validates :name, :is_available, presence: true

  # MODEL METHODS

  def available?
    is_available
  end
end
