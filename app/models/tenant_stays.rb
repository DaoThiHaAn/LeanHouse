class TenantStay < ApplicationRecord
  belongs_to :tenant, inverse_of: tenant_stays
  belongs_to :rental_unit, inverse_of: tenant_stays

  validates :check_out, comparison: { greater_than_or_equal_to: :check_in }, allow_nil: true
end
