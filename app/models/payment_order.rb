# frozen_string_literal: true

class PaymentOrder < ApplicationRecord
  belongs_to :invoice

  validates :provider, :order_code, presence: true
  validates :order_code, uniqueness: true

  scope :payos, -> { where(provider: "payos") }
  scope :pending, -> { where(status: "PENDING") }
  scope :paid, -> { where(status: "PAID") }

  def self.generate_order_code
    loop do
      candidate = rand(100_000_000..999_999_999)
      return candidate unless exists?(order_code: candidate)
    end
  end
end
