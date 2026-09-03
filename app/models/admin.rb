class Admin < ApplicationRecord
  has_secure_password

  enum :role, { super_admin: "super_admin", support: "support" }

  before_validation :normalize_inputs

  validates :fullname, presence: true, format: { with: /\A[\p{L}\s\.]+\z/, message: :invalid }
  validates :email,
            presence: true,
            uniqueness: { case_sensitive: false },
            format: { with: URI::MailTo::EMAIL_REGEXP, message: :invalid }
  validates :password, length: { in: 8..72 }, on: :create
  validates :password, length: { in: 8..72 }, allow_nil: true, on: :update
  validate :pw_complexity, if: -> { password.present? }
  validates :role, presence: true

  scope :active, -> { where(is_active: true) }

  def active?
    is_active
  end

  def super_admin?
    role == "super_admin"
  end


  private

  def normalize_inputs
    self.fullname = fullname&.squish
    self.email = email&.squish&.downcase
  end

  def pw_complexity
    return if password.blank?

    unless password.match?(/\d/) && password.match?(/[A-Za-z]/)
      errors.add(:password, :invalid_pw)
    end
  end
end
