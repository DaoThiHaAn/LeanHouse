class Tenant < ApplicationRecord
  self.primary_key = :id
  belongs_to :user, foreign_key: :id, primary_key: :id, inverse_of: :tenant
  has_many :tenant_stays,  inverse_of: :tenant
  has_many :contracts, inverse_of: :tenant
  has_many :requests, inverse_of: :tenant
  has_many :vehicles, inverse_of: :tenant, dependent: :destroy
  has_many :invoices, dependent: :nullify

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

  # Returns all distinct houses this tenant has ever been linked to
  def linked_houses
    stay_unit_ids = tenant_stays.select(:rental_unit_id)
    room_house_ids = House.joins(floors: { rooms: :rental_unit })
                          .where(rental_units: { id: stay_unit_ids })
                          .pluck(:id)
    bed_house_ids = House.joins(floors: { rooms: { beds: :rental_unit } })
                         .where(rental_units: { id: stay_unit_ids })
                         .pluck(:id)
    contract_house_ids = contracts.pluck(:house_id)
    request_house_ids = requests.pluck(:house_id)

    all_house_ids = (room_house_ids + bed_house_ids + contract_house_ids + request_house_ids).compact.uniq
    House.where(id: all_house_ids).sorted
  end
end
