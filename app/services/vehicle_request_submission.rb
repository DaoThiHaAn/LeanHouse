class VehicleRequestSubmission
  def self.call(...)
    new(...).call
  end

  def initialize(tenant:, house:, tenant_stay:, params:, accept_terms:, send_noti: true)
    @tenant = tenant
    @house = house
    @tenant_stay = tenant_stay
    @params = params
    @accept_terms = accept_terms
    @send_noti = send_noti
  end

  def call
    vehicle_request = VehicleRequest.new(params)
    vehicle_request.consent_given_at = Time.current if accept_terms == "1"

    if accept_terms != "1"
      vehicle_request.errors.add(:base, I18n.t("request.must_accept_terms"))
      raise ActiveRecord::RecordInvalid.new(vehicle_request)
    end

    request = nil
    ActiveRecord::Base.transaction do
      vehicle_request.save!
      request = tenant.requests.create!(
        house: house,
        requestable: vehicle_request
      )
    end

    send_notifications(request, vehicle_request) if @send_noti
    vehicle_request
  end

  private

  attr_reader :tenant, :house, :tenant_stay, :params, :accept_terms

  def send_notifications(request, vehicle_request)
    landlord_user = house.landlord.user
    tenant_user = tenant.user
    recipients = [ tenant_user, landlord_user ].compact.uniq

    VehicleRequestCreatedNotifier.with(
      request: request,
      tenant_name: tenant_user.fullname,
      house_id: house.id,
      house_name: house.name,
      location: tenant_stay&.rental_unit&.location_info,
      license_plate: vehicle_request.license_plate
    ).deliver_later(recipients)
  end
end
