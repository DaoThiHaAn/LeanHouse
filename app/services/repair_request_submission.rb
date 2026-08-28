class RepairRequestSubmission
  def self.call(...)
    new(...).call
  end

  def initialize(tenant:, house:, tenant_stay:, params:, send_noti: true)
    @tenant = tenant
    @house = house
    @tenant_stay = tenant_stay
    @params = params
    @send_noti = send_noti
  end

  def call
    repair_request = RepairRequest.new(params)

    request = nil
    ActiveRecord::Base.transaction do
      repair_request.save!
      request = tenant.requests.create!(
        house: house,
        requestable: repair_request
      )
    end

    send_notifications(request, repair_request) if @send_noti
    repair_request
  end

  private

  attr_reader :tenant, :house, :tenant_stay, :params

  def send_notifications(request, repair_request)
    landlord_user = house.landlord.user
    tenant_user = tenant.user
    recipients = [ tenant_user, landlord_user ].compact.uniq

    RepairRequestCreatedNotifier.with(
      request: request,
      tenant_name: tenant_user.fullname,
      house_id: house.id,
      house_name: house.name,
      location: tenant_stay&.rental_unit&.location_info,
      title: repair_request.title
    ).deliver_later(recipients)
  end
end
