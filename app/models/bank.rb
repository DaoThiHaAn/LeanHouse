class Bank < ApplicationRecord
  has_many :bank_accounts, dependent: :restrict_with_error

  validates :name, :code, :bin, :short_name, presence: true
  validates :bin, uniqueness: true
  validates :code, uniqueness: true

  scope :sorted, -> { order(short_name: :asc) }

  def display_name
    "#{short_name} - #{name}"
  end
end
