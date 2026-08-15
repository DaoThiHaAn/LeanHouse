class Bed < ApplicationRecord
  belongs_to :room, inverse_of: :beds, counter_cache: :max_slots, touch: true
  has_one :rental_unit, as: :rentable, dependent: :destroy
  has_one :house, through: :room
  has_many :tenant_stays, through: :rental_unit

  # A bed has many historical stays, but only one stay without a checkout date.
  has_one :staying_tenant_stay, -> { staying },
          through: :rental_unit,
          source: :tenant_stays
  has_one :staying_tenant, through: :staying_tenant_stay, source: :tenant

  validates :name, presence: true

  scope :active, -> { where(deleted: false) }
  scope :deleted, -> { where(deleted: true) }
  scope :sorted, -> { order(name: :asc) }
  scope :empty, -> { where(is_available: false) }
  scope :available, -> { where(is_available: true) }


  # MODEL METHODS

  def available?
    is_available
  end

  def available__for?(rental_unit)
    is_available
  end
end
