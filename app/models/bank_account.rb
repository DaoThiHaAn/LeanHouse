class BankAccount < ApplicationRecord
  MAX_ACCOUNTS = 10

  belongs_to :landlord, inverse_of: :bank_accounts
  belongs_to :bank
  has_many :invoices, dependent: :nullify

  before_validation :normalize_inputs
  before_save :ensure_single_default

  validates :account_number, :account_holder, presence: true
  validates :account_number, format: { with: /\A[0-9A-Za-z]+\z/, message: :invalid }
  validates :account_number, uniqueness: {
    scope: [ :landlord_id, :bank_id ],
    message: :already_added
  }
  validate :max_ten_accounts_per_landlord, on: :create

  scope :default_first, -> { order(is_default: :desc, created_at: :desc) }

  def display_label
    "#{bank.short_name} - #{account_number} (#{account_holder})"
  end

  private

  def normalize_inputs
    self.account_number = account_number&.strip
    self.account_holder = account_holder&.squish&.upcase
  end

  def ensure_single_default
    if is_default? && is_default_changed?
      landlord.bank_accounts.where.not(id: id).update_all(is_default: false)
    elsif landlord.bank_accounts.where.not(id: id).empty?
      self.is_default = true
    end
  end

  def max_ten_accounts_per_landlord
    if landlord && landlord.bank_accounts.count >= MAX_ACCOUNTS
      errors.add(:base, I18n.t("errors.bank_account_limit_reached", default: "Bạn chỉ có thể lưu tối đa #{MAX_ACCOUNTS} tài khoản ngân hàng."))
    end
  end
end
