class Contract < ApplicationRecord
  belongs_to :tenant
  belongs_to :house
  belongs_to :landlord
  has_many_attached :documents

  NEARLY_DUE_DAYS = 30
  ALLOWED_TYPES = %w[image/jpeg image/jpg image/png]

  before_validation :normalize_name

  validates :citizen_id, :start_date, :due_date, :name, presence: true
  validates :due_date,
    comparison: { greater_than: :start_date, message: :must_be_after_start_date }
  validates :citizen_id, format: { with: /\A\d{12}\z/ }
  # When a tenant is registerd for temporary residence, its due date must be set
  validates :temp_resid_due_date, presence: true, if: :temp_resid_registered?
  validates :temp_resid_due_date, comparison: { greater_than: -> { Date.current } }, if: :temp_resid_registered?
  validate :validate_documents

  scope :expiring_soonest, -> { order(due_date: :asc, id: :asc) }
  scope :latest_started, -> { order(start_date: :desc, id: :desc) }

  # Contract due scopes
  scope :overdue, -> { where("contracts.due_date < ?", Date.current) }
  scope :nearly_due, -> { where(contracts: { due_date: Date.current..(Date.current + NEARLY_DUE_DAYS.days) }) }

  # Temporary residence scopes
  scope :temp_resid_unregistered, -> { where(contracts: { temp_resid_registered: false }) }
  scope :temp_resid_overdue, -> { where(contracts: { temp_resid_registered: true }).where("contracts.temp_resid_due_date < ?", Date.current) }
  scope :temp_resid_nearly_due, -> { where(contracts: { temp_resid_registered: true, temp_resid_due_date: Date.current..(Date.current + NEARLY_DUE_DAYS.days) }) }

  scope :finished, -> { where.not(end_date: nil) }
  scope :unfinished, -> { where(end_date: nil) }

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

  def formatted_end_date
    end_date&.strftime("%d/%m/%Y") || "-"
  end

  def title_name
    I18n.t("form.contract.self") + " " + name
  end


  private

  def normalize_name
    self.name = name&.squish
  end

  def validate_documents
    if !documents.attached? || documents.empty?
      errors.add(:documents, :blank)
      return
    end
    if documents.length > 10
      errors.add(:documents, :too_long, count: 10)
    end
    documents.each do |doc|
      if doc.blob.byte_size > 20.megabytes
        errors.add(:documents, :file_too_big, size: "20MB")
      end
      unless ALLOWED_TYPES.include?(doc.blob.content_type)
        errors.add(:documents, :invalid_content_type)
      end
    end
  end
end
