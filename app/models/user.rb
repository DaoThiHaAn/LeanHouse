class User < ApplicationRecord
  has_secure_password
  has_one_attached :avatar
  has_one :landlord, dependent: :destroy

  validates :fullname, :tel, :password_digest, :sex, :bday, :address, presence: true
  validates :tel, uniqueness: true
  validates :sex, inclusion: { in: %w[M F], message: "%{value} is not a valid sex" }

  # Virtual attribute
  attr_accessor :role
end
