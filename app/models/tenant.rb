class Tenant < ApplicationRecord
  self.primary_key = :id
  belongs_to :user, foreign_key: :id, primary_key: :id, inverse_of: :tenant
  has_many :tenant_stays,  inverse_of: :tenant
  has_many :contracts, inverse_of: :tenant

  scope :name_sorted, -> { order("users.fullname ASC") }

  scope :search, ->(query) do
    return all if query.blank?
    q = "%#{sanitize_sql_like(query.strip)}%"
    joins(:user).where("unaccent(users.fullname) ILIKE unaccent(:q)", q: q)
  end

  # MODEL METHOD

  # Check if a tenant has been linked to a rental unit
  def linked?
    tenant_stays.staying.exists?
  end

  def current_stay
    tenant_stays.staying.first
  end

  # Return formatted string of the currennt staying info
  def current_staying_info
    current_stay&.rental_unit.location_info.to_s
  end

  def latest_contract
    contracts.latest_started.first
  end
end
