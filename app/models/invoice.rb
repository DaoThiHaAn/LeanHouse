class Invoice < ApplicationRecord
  enum :invoice_type, { room: "room", individual: "individual" }
  enum :status, { pending: "pending", paid: "paid", overdue: "overdue", cancelled: "cancelled" }
  enum :payment_method, { cash: "cash", transfer: "transfer" }

  has_one_attached :payment_proof

  belongs_to :house
  belongs_to :room
  belongs_to :tenant, optional: true
  belongs_to :bank_account, optional: true
  belongs_to :created_by, class_name: "User"
  belongs_to :paid_by, class_name: "User", optional: true
  belongs_to :undone_by, class_name: "User", optional: true

  has_many :invoice_items, dependent: :destroy
  has_many :service_usage_logs, dependent: :nullify

  before_validation :normalize_title
  before_validation :normalize_payment_method

  validates :code, :billing_month, :due_date, :status, :invoice_type, :title, presence: true
  validates :code, uniqueness: true
  validates :subtotal, :total_discount, :total_addition, :total_amount, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :payment_method, presence: true, if: :paid?
  validates :payment_method, absence: true, unless: :paid?

  scope :kept,       -> { where(discarded_at: nil) }
  scope :discarded,  -> { where.not(discarded_at: nil) }
  scope :for_month,  ->(m) { where(billing_month: m.to_date.beginning_of_month) if m.present? }
  scope :by_status,  ->(s) { where(status: s) if s.present? && statuses.key?(s.to_s) }
  scope :sorted,     -> { order(billing_month: :desc, created_at: :desc) }

  def payment_method=(val)
    val = "transfer" if val.to_s == "bank_transfer"
    super(val)
  end

  def mark_as_paid!(by_user: nil, method: "transfer", proof: nil, payment_note: nil)
    method = "transfer" if method.to_s == "bank_transfer" || method.blank?
    self.status = :paid
    self.paid_at = Time.current
    self.payment_method = method
    self.paid_by = by_user
    self.paid_by_role = by_user&.role
    self.undo_reason = nil
    if payment_note.present?
      self.note = [ note, payment_note ].compact_blank.join("\n")
    end
    payment_proof.attach(proof) if proof.present?
    save!
  end

  def undo_paid!(by_user:, explanation:)
    raise ArgumentError, "Explanation is required" if explanation.blank?

    new_status = due_date < Date.current ? :overdue : :pending
    timestamp_str = Time.current.strftime("%H:%M %d/%m/%Y")
    log_entry = "[Hủy xác nhận thanh toán bởi #{by_user.fullname} lúc #{timestamp_str}: #{explanation}]"

    self.status = new_status
    self.paid_at = nil
    self.payment_method = nil
    self.undo_reason = explanation
    self.undone_at = Time.current
    self.undone_by = by_user
    self.note = [ note, log_entry ].compact_blank.join("\n")
    save!
  end

  def cancel!(by_user)
    transaction do
      update!(
        status: :cancelled,
        discarded_at: Time.current,
        note: [ note, "[Hủy bởi #{by_user.fullname} lúc #{Time.current.strftime('%H:%M %d/%m/%Y')}]" ].compact_blank.join("\n")
      )
      service_usage_logs.update_all(invoice_id: nil)
    end
  end

  def overdue?
    status == "overdue" || (pending? && due_date < Date.current)
  end

  def target_users
    if individual? && tenant.present?
      Array(tenant.user)
    elsif house.bed?
      room.all_staying_bed_tenants.map { |i| i[:tenant].user }.compact.uniq
    else
      room.all_staying_tenants.map(&:user).compact.uniq
    end
  end

  def formatted_total_amount
    "#{total_amount.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1.').reverse}đ"
  end

  def self.generate_code(room, month)
    prefix = "HD#{month.strftime('%y%m')}"
    clean_room = room.name.gsub(/[^0-9A-Za-z]/, "").upcase[0..5]

    loop do
      random_suffix = SecureRandom.alphanumeric(4).upcase
      candidate_code = "#{prefix}-#{clean_room}-#{random_suffix}"
      return candidate_code unless Invoice.exists?(code: candidate_code)
    end
  end

  after_commit :broadcast_dashboard_update

  private

  def broadcast_dashboard_update
    LandlordDashboardBroadcaster.broadcast_later(house_id)
  end

  def normalize_title
    self.title = title&.squish
    self.note = note&.squish
  end

  def normalize_payment_method
    if paid?
      self.payment_method ||= "transfer"
    else
      self.payment_method = nil
    end
  end
end
