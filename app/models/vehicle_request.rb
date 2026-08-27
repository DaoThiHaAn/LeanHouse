class VehicleRequest < ApplicationRecord
  has_one :request, as: :requestable, dependent: :destroy

  has_one_attached :vehicle_photo
  has_one_attached :registration_card_image

  enum :vehicle_type, {
    motorbike: "motorbike",
    electric_bike: "electric_bike",
    bicycle: "bicycle",
    car: "car"
  }, default: :motorbike

  before_validation :normalize_attributes

  validates :license_plate, :vehicle_type, presence: true
  validates :consent_given_at, presence: true
  validates :registration_card_image, presence: true, on: :create
  validates :vehicle_photo, presence: true, on: :create

  # METHODS

  def self.vehicle_type_options
    vehicle_types.keys.map do |type|
      [ I18n.t("request.vehicle_types.#{type}", default: type.humanize), type ]
    end
  end

  # Purge sensitive registration paper
  def purge_documents!
    return if documents_purged_at.present?

    registration_card_image.purge_later if registration_card_image.attached?
    update_column(:documents_purged_at, Time.current)
  end

  # Called when landlord approves
  def approve!(landlord_user)
    raise "Request is no longer actionable" unless request.actionable?

    ActiveRecord::Base.transaction do
      # 1. Create official Vehicle record
      vehicle = Vehicle.create!(
        tenant: request.tenant,
        house: request.house,
        license_plate: license_plate,
        vehicle_type: vehicle_type,
        brand: brand,
        model: model,
        color: color
      )

      # 2. Transfer vehicle photo
      if vehicle_photo.attached?
        vehicle.vehicle_photo.attach(vehicle_photo.blob)
      end

      # 3. Update Request status to approved
      request.update!(
        status: :approved,
        resolved_by: landlord_user,
        resolved_at: Time.current
      )

      # 4. Purge the registration card image
      purge_documents!

      vehicle
    end
  end

  # Called when landlord rejects
  def reject!(landlord_user, reason = nil)
    raise "Request is no longer actionable" unless request.actionable?

    ActiveRecord::Base.transaction do
      request.update!(
        status: :rejected,
        rejection_reason: reason,
        resolved_by: landlord_user,
        resolved_at: Time.current
      )
      purge_documents!
    end
  end

  private

  def normalize_attributes
    self.license_plate = license_plate&.strip&.upcase
    self.brand = brand&.strip
    self.model = model&.strip
    self.color = color&.strip
  end
end
