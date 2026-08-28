class VehicleDeletion
  def self.call(...)
    new(...).call
  end

  def initialize(vehicle:, actor_user:, reason:, send_noti: true)
    @vehicle = vehicle
    @actor_user = actor_user
    @reason = reason.to_s.strip
    @send_noti = send_noti
  end

  def call
    validate_deletion!

    license_plate = vehicle.license_plate
    house = vehicle.house
    tenant = vehicle.tenant
    tenant_user = tenant.user
    landlord_user = house.landlord.user

    ActiveRecord::Base.transaction do
      vehicle.destroy!
    end

    if @send_noti
      recipients = [ tenant_user, landlord_user ].compact.uniq
      VehicleRemovedNotifier.with(
        license_plate: license_plate,
        house_id: house.id,
        house_name: house.name,
        tenant_name: tenant_user.fullname,
        reason: @reason,
        actor_role: @actor_user.role,
        actor_name: @actor_user.fullname
      ).deliver_later(recipients)
    end

    true
  end

  private

  attr_reader :vehicle, :actor_user, :reason

  def validate_deletion!
    if reason.blank?
      vehicle.errors.add(:base, I18n.t("errors.vehicle_delete_reason_required", default: "Vui lòng nhập lý do xóa phương tiện!"))
      raise ActiveRecord::RecordInvalid.new(vehicle)
    end
  end
end
