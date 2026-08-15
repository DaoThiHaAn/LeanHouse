class User < ApplicationRecord
  MIN_AGE = 15
  scope :kept, -> { where(discarded_at: nil) } # user is not deleted
  scope :registered, -> { where(discarded_at: nil).where.not(tel_verified_at: nil) }
  scope :name_sorted, -> { order(fullname: :asc) }

  # Virtual attribute
  attr_accessor :terms_accepted
  has_secure_password   # 2 virtual attributes: password, password_confirmation

  has_one_attached :avatar
  has_one :landlord, foreign_key: :id, primary_key: :id, inverse_of: :user, dependent: :destroy
  has_one :tenant, foreign_key: :id, primary_key: :id, inverse_of: :user, dependent: :destroy
  has_many :notifications,
    as: :recipient,
    dependent: :destroy,
    class_name: "Noticed::Notification"

  enum :role, { landlord: "landlord", tenant: "tenant" } # 2 methods: landlord?, tenant?
  enum :sex,  { male: "M", female: "F" } # 2 methods: male?, female?

  before_validation :normalize_inputs

  validates :fullname, :password_confirmation, :tel, :sex, :bday, :address, presence: true,  on: [ :create, :update ]
  validates :fullname, format: { with: /\A[\p{L}\s]+\z/, message: :invalid }, on: [ :create, :update ]
  validates :password, presence: true, on: [ :create, :pw_reset, :login ]

  validates :tel,
            format: { with: /\A0\d{9}\z/, message: :invalid },
            on: [ :create, :change_tel, :login ]
  validates :tel, uniqueness: {
              scope: :role,
              conditions: -> { where(discarded_at: nil).where.not(tel_verified_at: nil) },
              message: :existed_acc
            },
            on: [ :create, :change_tel ]

  validates :role, presence: true, on: [ :login, :create ]

  validates :terms_accepted, acceptance: true, on: :create

  validates :password, length: { in: 8..72 }, on: [ :create, :pw_reset ]
  validates :password_confirmation, length: { in: 8..72 },  on: [ :create, :pw_reset ]
  validates :bday, comparison: {
    less_than_or_equal_to: -> { MIN_AGE.years.ago.to_date },
    message: ->(object, data) { I18n.t("activerecord.errors.models.user.attributes.bday.invalid_bday", min_age: MIN_AGE) }
  },  on: [ :create, :update ]
  validate :pw_complexity, on: [ :create, :pw_reset ]
  validate :pw_match, on: [ :create, :pw_reset ]

  # Interface for controller
  include Otp

  def active?
    is_active
  end

  def discard!
    update!(discarded_at: Time.current)
  end

  # @param role ["landlord", "tenant"]
  def self.find_acc(tel, role)
    registered.find_by(tel: tel, role: role)
  end

  # Resize avatar
  def avatar_thumb
    avatar.variant(
      resize_to_fill: [ 128, 128 ],
      format: :webp,
      saver: {
        quality: 80
      }
    )
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
    self.fullname = fullname&.squish
    self.tel = tel&.squish
    self.address = address&.squish
  end
end
