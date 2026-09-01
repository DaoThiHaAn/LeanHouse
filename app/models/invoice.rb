class Invoice < ApplicationRecord
  enum :invoice_type, { room: "room", individual: "individual" }
  enum :status, { pending: "pending", paid: "paid", overdue: "overdue", cancelled: "cancelled" }

  belongs_to :house
  belongs_to :room
  belongs_to :tenant, optional: true
  belongs_to :bank_account, optional: true
  belongs_to :created_by, class_name: "User"

  has_many :invoice_items, dependent: :destroy
  has_many :service_usage_logs, dependent: :nullify

  validates :code, :billing_month, :due_date, :status, :invoice_type, presence: true
  validates :code, uniqueness: true
  validates :subtotal, :total_discount, :total_addition, :total_amount, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :kept,       -> { where(discarded_at: nil) }
  scope :discarded,  -> { where.not(discarded_at: nil) }
  scope :for_month,  ->(m) { where(billing_month: m.to_date.beginning_of_month) if m.present? }
  scope :by_status,  ->(s) { where(status: s) if s.present? && statuses.key?(s.to_s) }
  scope :sorted,     -> { order(billing_month: :desc, created_at: :desc) }

  def mark_as_paid!(method = "bank_transfer")
    update!(
      status: :paid,
      paid_at: Time.current,
      payment_method: method
    )
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
    pending? && due_date < Date.current
  end

  def self.generate_code(room, month)
    prefix = "HD#{month.strftime('%y%m')}"
    clean_room = room.name.gsub(/[^0-9A-Za-z]/, "").upcase[0..5]
    random = SecureRandom.hex(2).upcase
    "#{prefix}-#{clean_room}-#{random}"
  end
end
