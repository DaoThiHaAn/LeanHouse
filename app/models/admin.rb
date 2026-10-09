class Admin < ApplicationRecord
  has_secure_password

  attr_accessor :current_password

  def password=(new_password)
    @password = new_password.presence
    super
  end

  enum :role, { super_admin: "super_admin", support: "support" }

  before_validation :normalize_inputs

  validates :fullname, presence: true, format: { with: /\A[\p{L}\s\.]+\z/, message: :invalid }
  validates :email,
            presence: true,
            uniqueness: { case_sensitive: false },
            format: { with: URI::MailTo::EMAIL_REGEXP, message: :invalid }
  validates :password, length: { in: 8..72 }, on: [ :create, :change_password ]
  validates :password, length: { in: 8..72 }, allow_nil: true, on: :update
  validate :pw_complexity, if: -> { password.present? }
  validates :role, presence: true
  validate :single_super_admin, if: -> { super_admin? && (new_record? || role_changed?) }

  validates :current_password, presence: true, on: :change_password
  validate :current_password_matches, on: :change_password
  validates :password, presence: true, on: :change_password

  scope :active, -> { where(is_active: true) }

  def active?
    is_active
  end

  def super_admin?
    role == "super_admin"
  end


  private

  def normalize_inputs
    self.fullname = fullname.to_s.squish
    self.email = email.to_s.squish.downcase
  end

  def pw_complexity
    return if password.blank?

    unless password.match?(/\d/) && password.match?(/[A-Za-z]/)
      errors.add(:password, :invalid_pw)
    end
  end

  def single_super_admin
    existing = Admin.where(role: "super_admin")
    existing = existing.where.not(id: id) if persisted?
    if existing.exists?
      errors.add(:role, :single_super_admin)
    end
  end

  def current_password_matches
    return if current_password.blank?

    expected_digest = password_digest_was || password_digest
    return if expected_digest.blank?

    unless BCrypt::Password.new(expected_digest).is_password?(current_password)
      errors.add(:current_password, :invalid)
    end
  end
end
