class LeaveHouseRequestSubmission
  def self.call(...)
    new(...).call
  end

  def initialize(tenant:, house:, tenant_stay:, send_noti: true)
    @tenant = tenant
    @house = house
    @tenant_stay = tenant_stay
    @send_noti = send_noti
  end

  def call
    validate_submission!

    leave_house_request = LeaveHouseRequest.new
    request = nil

    ActiveRecord::Base.transaction do
      leave_house_request.save!
      request = tenant.requests.create!(
        house: house,
        requestable: leave_house_request
      )
    end

    send_notifications(request) if @send_noti
    leave_house_request
  end

  private

  attr_reader :tenant, :house, :tenant_stay

  def validate_submission!
    if tenant_stay.blank? || tenant_stay.checkout_at.present?
      leave_req = LeaveHouseRequest.new
      leave_req.errors.add(:base, I18n.t("request.create_note", default: "Để tạo yêu cầu, bạn cần đang ở trong nhà này!"))
      raise ActiveRecord::RecordInvalid.new(leave_req)
    end

    if tenant.requests.pending.where(house: house, requestable_type: "LeaveHouseRequest").exists?
      leave_req = LeaveHouseRequest.new
      leave_req.errors.add(:base, I18n.t("request.already_pending_leave_house", default: "Bạn đã có một yêu cầu rời nhà đang chờ xét duyệt cho nhà này!"))
      raise ActiveRecord::RecordInvalid.new(leave_req)
    end
  end

  def send_notifications(request)
    landlord_user = house.landlord.user
    tenant_user = tenant.user
    recipients = [ tenant_user, landlord_user ].compact.uniq

    LeaveHouseRequestCreatedNotifier.with(
      request: request,
      tenant_name: tenant_user.fullname,
      house_id: house.id,
      house_name: house.name,
      location: tenant_stay&.rental_unit&.location_info
    ).deliver_later(recipients)
  end
end
