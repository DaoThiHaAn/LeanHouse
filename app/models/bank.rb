class Bank < ApplicationRecord
  has_many :bank_accounts, dependent: :restrict_with_error

  validates :name, :code, :bin, :short_name, presence: true
  validates :bin, uniqueness: true
  validates :code, uniqueness: true

  scope :sorted, -> { order(short_name: :asc) }
  scope :payos_supported, -> { where(bin: BankAccount::PAYOS_SUPPORTED_BINS).or(where(code: BankAccount::PAYOS_SUPPORTED_CODES)) }

  def display_name
    "#{short_name} - #{name}"
  end

  def payos_supported?
    BankAccount::PAYOS_SUPPORTED_BINS.include?(bin.to_s) ||
      BankAccount::PAYOS_SUPPORTED_CODES.include?(code.to_s.upcase)
  end
end
