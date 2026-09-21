class BankAccount < ApplicationRecord
  MAX_ACCOUNTS = 10

  # Encrypt sensitive PayOS API credentials at rest.
  # Decryption is transparent — read/write .payos_api_key etc. as plain strings normally.
  # support_unencrypted_data: true is set in application.rb until the data migration runs.
  encrypts :payos_api_key, :payos_checksum_key, :payos_client_id

  belongs_to :landlord, inverse_of: :bank_accounts
  belongs_to :bank
  has_many :invoices, dependent: :nullify

  alias_attribute :account_name, :account_holder

  attr_accessor :consent_accepted

  before_validation :normalize_inputs
  before_save :ensure_single_default
  after_destroy :ensure_has_default

  validates :account_number, :account_holder, presence: true
  validates :account_number, format: { with: /\A[0-9A-Za-z]+\z/, message: :invalid }
  validates :account_number, uniqueness: {
    scope: [ :landlord_id, :bank_id ],
    message: :already_added
  }
  validates :consent_accepted, acceptance: true, on: :create, if: -> { !consent_accepted.nil? }
  validate :max_ten_accounts_per_landlord, on: :create

  validates :payos_client_id, :payos_api_key, :payos_checksum_key, presence: true, if: :payos_enabled?
  validate :validate_payos_bank_support, if: :payos_enabled?

  scope :default_first, -> { order(is_default: :desc, created_at: :desc) }

  PAYOS_SUPPORTED_BINS = %w[970422 970416 970418 970448 970452].freeze
  PAYOS_SUPPORTED_CODES = %w[MB ACB BIDV OCB KLB].freeze

  def payos_supported_bank?
    bank&.payos_supported? || false
  end

  def payos_configured?
    payos_enabled? && payos_client_id.present? && payos_api_key.present? && payos_checksum_key.present?
  end

  def display_label
    "#{bank.short_name} - #{account_number} (#{account_holder})"
    label = "#{bank.short_name} - #{account_number} (#{account_holder})"
    label += " [payOS]" if payos_configured?
    label
  end

  def has_unpaid_invoices?
    invoices.where(status: %i[pending overdue]).exists?
  end

  private

  def normalize_inputs
    self.account_number = account_number&.strip
    self.account_holder = account_holder&.squish&.upcase
    self.payos_client_id = payos_client_id&.strip
    self.payos_api_key = payos_api_key&.strip
    self.payos_checksum_key = payos_checksum_key&.strip
  end

  def validate_payos_bank_support
    unless payos_supported_bank?
      errors.add(:base, I18n.t("bank_account.errors.payos_unsupported_bank", default: "Ngân hàng này hiện chưa được hỗ trợ liên kết tự động qua payOS."))
    end
  end

  def ensure_single_default
    if is_default? && is_default_changed?
      landlord.bank_accounts.where.not(id: id).update_all(is_default: false)
    elsif landlord.bank_accounts.where.not(id: id).empty?
      self.is_default = true
    end
  end

  def ensure_has_default
    if is_default? && landlord&.bank_accounts&.any?
      landlord.bank_accounts.first.update_column(:is_default, true)
    end
  end

  def max_ten_accounts_per_landlord
    if landlord && landlord.bank_accounts.count >= MAX_ACCOUNTS
      errors.add(:base, I18n.t("errors.bank_account_limit_reached", default: "Bạn chỉ có thể lưu tối đa #{MAX_ACCOUNTS} tài khoản ngân hàng."))
    end
  end
end
