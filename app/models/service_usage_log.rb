class ServiceUsageLog < ApplicationRecord
  has_one_attached :reading_photo

  belongs_to :room
  belongs_to :service, optional: true
  belongs_to :service_variant, optional: true
  belongs_to :invoice, optional: true
  belongs_to :submitted_by, polymorphic: true, optional: true
  belongs_to :confirmed_by, class_name: "User", optional: true

  validates :service_name, :unit, :billing_month, :start_date, :end_date, presence: true
  validates :prev_reading, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :latest_reading, numericality: { only_integer: true, greater_than_or_equal_to: :prev_reading }, allow_nil: true
  validate :prevent_modification_when_confirmed, on: :update

  before_save :compute_usage

  scope :confirmed,   -> { where(is_confirmed: true) }
  scope :unconfirmed, -> { where(is_confirmed: false) }
  scope :unbilled,    -> { where(invoice_id: nil) }
  scope :for_month,   ->(month) { where(billing_month: month.to_date.beginning_of_month) }
  scope :sorted,      -> { order(billing_month: :desc, created_at: :desc) }

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
      super(val&.to_date&.beginning_of_month)
    end
  end

  attr_accessor :allow_landlord_override

  def billed?
    invoice_id.present?
  end

  def can_be_edited_by_tenant?
    !is_confirmed? && !billed?
  end

  def real_time?
    service_variant&.is_real_time? || false
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

  def prevent_modification_when_confirmed
    return if allow_landlord_override

    # If it was confirmed and confirmed state is not being toggled, lock readings and photo from being changed
    if is_confirmed_was && !is_confirmed_changed?
      if latest_reading_changed? || prev_reading_changed? || start_date_changed? || end_date_changed?
        errors.add(:base, I18n.t("errors.service_usage_log_locked", default: "Chỉ số đã được xác nhận, không thể chỉnh sửa."))
      end
    end
  end
end
