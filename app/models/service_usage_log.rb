class ServiceUsageLog < ApplicationRecord
  has_one_attached :reading_photo

  belongs_to :room
  belongs_to :service, optional: true
  belongs_to :service_variant, optional: true
  has_many :invoice_service_usage_logs, dependent: :destroy
  has_many :invoices, through: :invoice_service_usage_logs
  belongs_to :submitted_by, polymorphic: true, optional: true
  belongs_to :confirmed_by, class_name: "User", optional: true

  # Convenience backward-compatible accessors for primary/first invoice
  def invoice
    invoices.first
  end

  def invoice=(inv)
    self.invoices = inv ? [ inv ] : []
  end

  validates :service_name, :unit, :billing_month, :start_date, :end_date, presence: true
  validates :prev_reading, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  # latest_reading is required immediately if confirmed; optional if awaiting tenant photo/reading
  validates :latest_reading, presence: true, if: :is_confirmed?
  validates :latest_reading, numericality: { only_integer: true }, allow_nil: true
  validates :service_id,
            uniqueness: {
              scope: %i[room_id billing_month],
              message: ->(_object, _data) { I18n.t("activerecord.errors.models.service_usage_log.attributes.service_id.taken") }
            },
            if: :service_id?
  validate :latest_reading_greater_than_or_equal_to_prev_reading
  validate :prevent_modification_when_confirmed, on: :update

  before_save :compute_usage
  before_validation :mark_non_billable_for_vacant_room, on: :create
  before_destroy :prevent_destroy_if_billed, prepend: true

  scope :confirmed,   -> { where(is_confirmed: true) }
  scope :unconfirmed, -> { where(is_confirmed: false) }
  scope :billed,      -> { where(id: InvoiceServiceUsageLog.select(:service_usage_log_id)) }
  scope :unbilled,    -> { where.not(id: InvoiceServiceUsageLog.select(:service_usage_log_id)) }
  scope :billable,    -> { where(billable: true) }
  scope :for_month,   ->(month) { where(billing_month: month.to_date.beginning_of_month) }
  scope :sorted,      -> { order(billing_month: :desc, created_at: :desc) }

  # Custom setter method: always parse the billing_month to the 1st date of the month
  def billing_month=(val)
    if val.is_a?(String) && val.match?(/\A\d{4}-\d{2}\z/)
      super(Date.parse("#{val}-01").beginning_of_month)
    elsif val.is_a?(String) && val.present?
      begin
        super(Date.parse(val).beginning_of_month)
      rescue ArgumentError
        super(nil)
      end
    else
      super(val ? val.to_date.beginning_of_month : nil)
    end
  end

  attr_accessor :allow_landlord_override

  # Retrieves the closest previous meter reading for a given room & service before the target month.
  # Fallbacks to 0 if no prior logs exist.
  def self.previous_reading_for(room:, service_id:, before_month:)
    return 0 unless room && service_id

    last_log = where(room_id: room.id, service_id: service_id)
                 .where("billing_month < ?", before_month)
                 .order(billing_month: :desc, created_at: :desc)
                 .first

    last_log ? (last_log.latest_reading || last_log.prev_reading || 0) : 0
  end

  def billed?
    if invoice_service_usage_logs.loaded?
      invoice_service_usage_logs.any?
    else
      invoice_service_usage_logs.exists?
    end
  end

  # Tenants can only edit or upload meter photos if the log is not yet confirmed by the landlord
  # and has not already been billed into an invoice.
  def can_be_edited_by_tenant?
    !is_confirmed? && !billed?
  end

  def real_time?
    service_variant ? service_variant.is_real_time? : false
  end

  def total_amount
    (usage_quantity || 0) * (unit_price || 0)
  end

  def compute_usage
    if latest_reading.present? && prev_reading.present?
      self.usage_quantity = [ latest_reading - prev_reading, 0 ].max
    end
  end

  private

  # Persist vacancy at creation time so a later move-in cannot make an old
  # vacant-period reading chargeable.
  def mark_non_billable_for_vacant_room
    self.billable = false if room.empty?
  end

  def latest_reading_greater_than_or_equal_to_prev_reading
    return if latest_reading.blank? || prev_reading.blank?
    return if errors[:prev_reading].any? || errors[:latest_reading].any?
    return unless latest_reading.is_a?(Numeric) && prev_reading.is_a?(Numeric)

    if latest_reading < prev_reading
      errors.add(:latest_reading, :greater_than_or_equal_to_prev, count: prev_reading)
    end
  end

  def prevent_modification_when_confirmed
    return if allow_landlord_override

    # If it was confirmed and confirmed state is not being toggled, lock readings and photo from being changed
    if is_confirmed_was && !is_confirmed_changed?
      if latest_reading_changed? || prev_reading_changed? || start_date_changed? || end_date_changed?
        errors.add(:base, I18n.t("errors.service_usage_log_locked", default: "Chỉ số đã được xác nhận, không thể chỉnh sửa."))
      end
    end
  end

  def prevent_destroy_if_billed
    if billed?
      errors.add(:base, I18n.t("service_usage_logs.cannot_delete_billed", default: "Chỉ số này đã được xuất hóa đơn, không thể xóa!"))
      throw :abort
    end
  end
end
