class Contract < ApplicationRecord
  belongs_to :tenant
  belongs_to :house
  belongs_to :landlord

  NEARLY_DUE_DAYS = 30

  before_validation :normalize_name

  validates :citizen_id, :start_date, :due_date, :name, presence: true
  validates :due_date, comparison: { greater_than: :start_date }
  validates :citizen_id, format: { with: /\A\d{12}\z/ }
  # When a tenant is registerd for temporary residence, its due date must be set
  validates :temp_resid_due_date, presence: true, if: :temp_resid_registered?

  scope :expiring_soonest, -> { order(due_date: :asc, id: :asc) }
  scope :latest_started, -> { order(start_date: :desc, id: :desc) }

  # Contract due scopes
  scope :overdue, -> { where("contracts.due_date < ?", Date.current) }
  scope :nearly_due, -> { where(contracts: { due_date: Date.current..(Date.current + NEARLY_DUE_DAYS.days) }) }

  # Temporary residence scopes
  scope :temp_resid_unregistered, -> { where(contracts: { temp_resid_registered: false }) }
  scope :temp_resid_overdue, -> { where(contracts: { temp_resid_registered: true }).where("contracts.temp_resid_due_date < ?", Date.current) }
  scope :temp_resid_nearly_due, -> { where(contracts: { temp_resid_registered: true, temp_resid_due_date: Date.current..(Date.current + NEARLY_DUE_DAYS.days) }) }

  # METHODS

  # Generate the status of the contract
  # @return [Symbol]
  def due_status
    return :overdue if due_date < Date.current
    return :nearly_due if due_date <= Date.current + NEARLY_DUE_DAYS.days
    :normal
  end

  # Generate the status of the temporary residence register
  # @return [Symbol]
  def temp_resid_due_status
    return :overdue if temp_resid_due_date < Date.current
    return :nearly_due if temp_resid_due_date <= Date.current + NEARLY_DUE_DAYS.days
    :normal
  end


  private

  def noralize_name
    self.name = name&.squish
  end
end
