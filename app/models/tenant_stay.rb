class TenantStay < ApplicationRecord
  belongs_to :tenant, inverse_of: :tenant_stays
  belongs_to :rental_unit, inverse_of: :tenant_stays

  validates :checkout_at, comparison: { greater_than_or_equal_to: :checkin_at }, allow_nil: true

  scope :staying, -> { where(checkout_at: nil) }
  scope :without_contract, -> { where(has_contract: false) }
  scope :with_contract, -> { where(has_contract: true) }


  # MODEL METHODS
  def contract
    rental_unit&.house&.contracts&.unfinished&.find_by(tenant_id: tenant_id)
  end
end
