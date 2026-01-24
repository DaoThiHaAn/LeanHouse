class Room < ApplicationRecord
  belongs_to :floor, inverse_of: :rooms

  validates :name, :max_slots, :tenants_count, :area, :rent, presence: true
  validates :max_slots, :rent, comparison: { greater_than: 0 }
  validates :tenants_count, comparison: { greater_than_or_equal_to: 0 }

  def available?
    tenants_count < max_slots
  end

  def empty?
    tenants_count.zero?
  end
end
