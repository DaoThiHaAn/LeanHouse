class InvoiceItem < ApplicationRecord
  enum :item_type, {
    rent: "rent",
    metered_service: "metered_service",
    fixed_service: "fixed_service",
    addition: "addition",
    discount: "discount"
  }

  belongs_to :invoice
  belongs_to :service_variant, optional: true

  validates :name, :item_type, presence: true
  validates :quantity, numericality: { greater_than_or_equal_to: 0 }
  validates :unit_price, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :amount, numericality: { only_integer: true }

  def discount?
    item_type.to_s == "discount"
  end

  def service?
    metered_service? || fixed_service?
  end

  def formatted_amount
    discount? ? "-#{amount.abs}" : amount.to_s
  end
end
