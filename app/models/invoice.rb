class Invoice < ApplicationRecord
  enum :invoice_type, { room: "room", individual: "individual", custom: "custom" }
  enum :status, { pending: "pending", paid: "paid", overdue: "overdue", cancelled: "cancelled" }
  enum :payment_method, { cash: "cash", transfer: "transfer" }

  attr_accessor :transfer_note_mode

  has_one_attached :payment_proof

  belongs_to :house
  belongs_to :room
  belongs_to :tenant, optional: true
  belongs_to :bank_account, optional: true
  belongs_to :created_by, class_name: "User"
  belongs_to :paid_by, class_name: "User", optional: true
  belongs_to :undone_by, class_name: "User", optional: true

  has_many :invoice_items, dependent: :destroy
  has_many :invoice_service_usage_logs, dependent: :destroy
  has_many :service_usage_logs, through: :invoice_service_usage_logs
  has_many :payment_orders, dependent: :destroy
  has_one :payos_order, -> { where(provider: "payos").order(id: :desc) }, class_name: "PaymentOrder"

  before_validation :normalize_title
  before_validation :normalize_payment_method
  before_validation :set_default_transfer_note

  validates :code, :billing_month, :due_date, :status, :invoice_type, :title, presence: true
  validates :code, uniqueness: true
  validates :subtotal, :total_discount, :total_addition, :total_amount, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :payment_method, presence: true, if: :paid?
  validates :payment_method, absence: true, unless: :paid?
  validate :prevent_update_when_paid, on: :update

  scope :kept,       -> { where(discarded_at: nil) }
  scope :discarded,  -> { where.not(discarded_at: nil) }
  scope :for_month,  ->(m) { where(billing_month: m.to_date.beginning_of_month) if m.present? }
  scope :by_status,  ->(s) { where(status: s) if s.present? && statuses.key?(s.to_s) }
  scope :sorted,     -> { order(billing_month: :desc, created_at: :desc) }

  def kept?
    discarded_at.nil?
  end

  def discarded?
    discarded_at.present?
  end

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
    self.paid_by_role = by_user&.role || (payment_note.to_s.include?("payOS") ? "payos" : nil)
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
    if paid?
      raise ArgumentError, I18n.t("invoice.errors.cannot_cancel_paid", default: "Không thể hủy hóa đơn đã xác nhận thanh toán. Vui lòng hủy xác nhận thanh toán trước.")
    end

    transaction do
      update!(
        status: :cancelled,
        discarded_at: Time.current,
        note: [ note, "[Hủy bởi #{by_user.fullname} lúc #{Time.current.strftime('%H:%M %d/%m/%Y')}]" ].compact_blank.join("\n")
      )
      invoice_service_usage_logs.destroy_all
    end
  end

  def overdue?
    status == "overdue" || (pending? && due_date < Date.current)
  end

  def target_users
    if (individual? || custom?) && tenant.present?
      Array(tenant.user)
    elsif house.bed?
      room.all_staying_bed_tenants.map { |i| i[:tenant].user }.compact.uniq
    else
      room.all_staying_tenants.map(&:user).compact.uniq
    end
  end

  def room_title
    room&.full_title
  end

  def target_name(include_room: true)
    room_str = room_title

    if (individual? || custom?) && tenant&.user.present?
      name = tenant.user.fullname
      (include_room && room_str.present?) ? "#{name} (#{room_str})" : name
    elsif room_str.present?
      room_str
    else
      house&.name
    end
  end

  def rent_items
    invoice_items.select(&:rent?)
  end

  def service_items
    invoice_items.select(&:service?)
  end

  def discount_items
    invoice_items.select(&:discount?)
  end

  def addition_items
    invoice_items.select(&:addition?)
  end

  def rent_total
    rent_items.sum(&:amount)
  end

  def services_total
    service_items.sum(&:amount)
  end

  def discounts_total
    discount_items.sum { |i| i.amount.abs }
  end

  def additions_total
    addition_items.sum(&:amount)
  end

  def effective_start_date
    start_date || billing_month.beginning_of_month
  end

  def effective_end_date
    end_date || billing_month.end_of_month
  end

  def payment_period_text
    "#{effective_start_date.strftime('%d/%m/%Y')} - #{due_date.strftime('%d/%m/%Y')}"
  end

  def rent_period_text
    "#{effective_start_date.strftime('%d/%m/%Y')} - #{effective_end_date.strftime('%d/%m/%Y')}"
  end

  def transfer_note
    val = read_attribute(:transfer_note)
    return val if val.present?
    return nil if persisted? || transfer_note_mode == "none"
    return nil unless room.present? && house.present?

    TransferNoteBuilder.build(house.transfer_note_template, self)
  end

  def build_fallback_transfer_note
    return nil if transfer_note_mode == "none"
    return code unless room.present? && house.present?

    TransferNoteBuilder.build(house.transfer_note_template, self)
  end

  def payos_configured?(account = bank_account)
    account&.payos_configured?
  end

  def ensure_payos_order!(account = bank_account)
    return nil unless payos_configured?(account)

    existing = payment_orders.find_by(provider: "payos")
    if existing
      association(:payos_order).target = existing
      return existing
    end

    order = payment_orders.create!(
      provider: "payos",
      order_code: PaymentOrder.generate_order_code,
      status: "PENDING"
    )
    association(:payos_order).target = order
    order
  end

  def payos_order_code(account = bank_account)
    return nil unless payos_configured?(account)

    (payos_order || ensure_payos_order!(account))&.order_code
  end

  def payos_checkout_url
    payos_order&.checkout_url
  end

  def payos_qr_code
    payos_order&.qr_code
  end

  def payos_status
    payos_order&.status
  end

  def paid_via_payos?
    paid? && (paid_by_role == "payos" || payos_order&.status == "PAID" || note.to_s.include?("payOS"))
  end

  def ensure_payos_payment_link!(account = bank_account)
    return nil unless payos_configured?(account)
    return payos_order if payos_order&.checkout_url.present?
    return nil if paid? || cancelled?

    PayosService.create_payment_link(self)
    payos_order
  end

  def payos_transfer_description(account = bank_account)
    code = payos_order_code(account)
    code.present? ? "HD #{code}" : transfer_note
  end

  def effective_bank_account_number(account = bank_account)
    if payos_configured?(account) && payos_order&.metadata&.dig("accountNumber").present?
      payos_order.metadata["accountNumber"]
    else
      account&.account_number
    end
  end

  def effective_transfer_note(account = bank_account)
    if payos_configured?(account)
      payos_order&.metadata&.dig("description").presence || payos_transfer_description(account)
    else
      transfer_note
    end
  end

  def vietqr_url(account = bank_account)
    return unless account

    if payos_configured?(account) && payos_order&.checkout_url.present? && payos_order.metadata&.dig("accountNumber").present?
      bin = payos_order.metadata["bin"].presence || account.bank&.bin
      acc_num = payos_order.metadata["accountNumber"]
      desc = payos_order.metadata["description"].presence || payos_transfer_description(account)
      acc_name = payos_order.metadata["accountName"].presence || account.account_holder

      return VietqrService.generate_raw_url(
        bin: bin,
        account_number: acc_num,
        account_holder: acc_name,
        amount: total_amount,
        description: desc
      )
    end

    desc = if account.payos_configured?
             payos_transfer_description(account)
    else
             transfer_note
    end

    VietqrService.generate_url(
      bank_account: account,
      amount: total_amount,
      description: desc
    )
  end

  def self.generate_code(room, date = Date.current)
    d = date.to_date
    prefix = "HD#{d.strftime('%d%m%Y')}"
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


  def set_default_transfer_note
    if transfer_note_mode == "none"
      self.transfer_note = nil
      return
    end

    if transfer_note_mode == "custom"
      self.transfer_note = transfer_note.presence
      return
    end

    return if read_attribute(:transfer_note).present?
    return unless room.present? && house.present?

    self.transfer_note = TransferNoteBuilder.build(house.transfer_note_template, self)
  end

  def normalize_payment_method
    if paid?
      self.payment_method ||= "transfer"
    else
      self.payment_method = nil
    end
  end

  def prevent_update_when_paid
    if status_was == "paid"
      if status == "cancelled"
        errors.add(:base, I18n.t("invoice.errors.cannot_cancel_paid", default: "Không thể hủy hóa đơn đã xác nhận thanh toán. Vui lòng hủy xác nhận thanh toán trước."))
      elsif status == "paid"
        ignored_keys = %w[updated_at]
        if (changes.keys - ignored_keys).any?
          errors.add(:base, I18n.t("invoice.errors.cannot_update_paid", default: "Không thể chỉnh sửa hóa đơn đã xác nhận thanh toán. Vui lòng hủy xác nhận thanh toán trước nếu cần thay đổi."))
        end
      end
    end
  end
end
