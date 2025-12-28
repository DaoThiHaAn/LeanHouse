class User < ApplicationRecord
  MIN_AGE = 15
  scope :kept, -> { where(discarded_at: nil) } # user is not deleted
  scope :registered, -> { where(discarded_at: nil).where.not(tel_verified_at: nil) }

  # Virtual attribute
  attr_accessor :terms_accepted
  has_secure_password   # 2 virtual attributes: password, password_confirmation

  has_one_attached :avatar
  has_one :landlord, foreign_key: :id, primary_key: :id, inverse_of: :user, dependent: :destroy
  has_one :tenant, foreign_key: :id, primary_key: :id, inverse_of: :user, dependent: :destroy

  before_validation :normalize_inputs

  validates :fullname, :password, :password_confirmation, :tel, :sex, :bday, :address, presence: true
  validates :fullname, format: { with: /\A[\p{L}\s]+\z/, message: :invalid_fname }
  validates :tel, length: { is: 10 },
            format: { with: /\A0\d{9}\z/, message: :invalid_tel },
            uniqueness: {
              scope: :role,
              conditions: -> { where(discarded_at: nil).where.not(tel_verified_at: nil) },
              message: :existed_acc
            },
            on: [ :signup, :change_tel ]
  validates :sex, inclusion: { in: %w[M F] }
  validates :terms_accepted, acceptance: true, on: :create

  validates :password, length: { in: 8..72 }
  validates :password_confirmation, length: { in: 8..72 }
  validate :pw_complexity, on: [ :signup, :pw_reset ]
  validate :pw_match, on: [ :signup, :pw_reset ]

  # Interface for controller
  include Otp

  def active?
    is_active
  end

  def discard!
    update!(discarded_at: Time.current)
  end

  def self.find_acc(tel, role)
    registered.find_by(tel: tel, role: role)
  end

  private

  def pw_complexity
    unless password.match?(/\d/) && password.match?(/[A-Za-z]/)
      errors.add(:password, :invalid_pw)
    end
  end

  def pw_match
    if password != password_confirmation
      errors.add(:password_confirmation, :confirmation)
    end
  end

  def normalize_inputs
    # Remove leading/trailing whitespace from string fields
    self.fullname = fullname.strip if fullname.present?
    self.tel = tel.strip if tel.present?
    self.address = address.strip if address.present?
  end
end
