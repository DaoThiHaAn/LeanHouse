# frozen_string_literal: true

class PaymentOrder < ApplicationRecord
  belongs_to :invoice

  validates :provider, :order_code, presence: true
  validates :order_code, uniqueness: true

  scope :payos, -> { where(provider: "payos") }
  scope :pending, -> { where(status: "PENDING") }
  scope :paid, -> { where(status: "PAID") }

  def self.generate_order_code
    # Use a PostgreSQL sequence for atomic, collision-free order code generation.
    # Unlike rand() + loop, nextval() is guaranteed unique at the DB level with
    # no race conditions and no retry logic needed.
    ActiveRecord::Base.connection
                      .select_value("SELECT nextval('payos_order_code_seq')")
                      .to_i
  end
end
