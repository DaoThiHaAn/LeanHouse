class Tenant < ApplicationRecord
  self.primary_key = :id
  belongs_to :user, foreign_key: :id, primary_key: :id, inverse_of: :tenant
  has_many :tenant_stays,  inverse_of: :tenant

  # MODEL METHOD

  def linked?
    tenant_stays.exists?(check_out: nil)
  end
end
