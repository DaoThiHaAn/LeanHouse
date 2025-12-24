class User < ApplicationRecord
  MIN_AGE = 15
  scope :kept, -> { where(discarded_at: nil) } # user is not deleted
  scope :existed,  -> { where(discarded_at: nil, tel_verified_at: nil) }

  # Virtual attribute
  attr_accessor :terms_accepted
  has_secure_password   # 2 virtual attributes: password, password_confirmation

  has_one_attached :avatar
  has_one :landlord, dependent: :destroy
  has_one :tenant, dependent: :destroy

  before_validation :normalize_inputs
  before_create :send_tel_otp

  include Otp

  validates :fullname, :password, :password_confirmation, :tel, :sex, :bday, :address, presence: true
  validates :fullname, format: { with: /\A[\p{L}\s]+\z/, message: :invalid_fname }
  validates :tel, length: { is: 10 },
            format: { with: /\A0\d{9}\z/, message: :invalid_tel },
            uniqueness: {
              scope: :role,
              conditions: -> { where(discarded_at: nil).where.not(tel_verified_at: nil) },
              message: :existed_acc
            }
  validates :sex, inclusion: { in: %w[M F] }
  validates :terms_accepted, acceptance: true, on: :create

  validates :password, length: { in: 8..72 }
  validates :password_confirmation, length: { in: 8..72 }
  validate :pw_complexity
  validate :pw_match


  def tel_verified?
    tel_verified_at.present?
  end

  def active?
    is_active
  end
  # OTP
  def send_tel_otp
    self.tel_verified = false
    self.otp_code = SecureRandom.random_number(1_000_000).to_s.rjust(6, "0")
    self.otp_sent_at = Time.current
    puts "OTP for #{tel}: #{otp_code}"
  end

  def verify_tel!(otp)
    return false if discarded?
    return false if otp_code != otp
    return false if otp_sent_at < OTP_EXPIRY.ago

    update!(
      tel_verified: true,
      otp_code: nil,
      otp_sent_at: nil
    )
  end

  def discard!
    update!(discarded_at: Time.current)
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
