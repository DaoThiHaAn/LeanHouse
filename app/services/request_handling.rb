class RequestHandling
  def self.call(...)
    new(...).call
  end

  def initialize(request:, landlord_user:, decision:, rejection_reason: nil, send_noti: true)
    @request = request
    @landlord_user = landlord_user
    @decision = decision.to_s
    @rejection_reason = rejection_reason.to_s.strip
    @send_noti = send_noti
  end

  def call
    validate_actionable!

    case decision
    when "approved"
      handle_approval!
    when "rejected"
      handle_rejection!
    else
      request.errors.add(:base, I18n.t("errors.unprocessable_entity", default: "Dữ liệu không hợp lệ!"))
      raise ActiveRecord::RecordInvalid.new(request)
    end

    send_notification if send_noti

    request
  end

  private

  attr_reader :request, :landlord_user, :decision, :rejection_reason, :send_noti

  def validate_actionable!
    unless request.actionable?
      request.errors.add(:base, I18n.t("errors.request_not_actionable", default: "Yêu cầu đã được xử lý hoặc đã hết hiệu lực!"))
      raise ActiveRecord::RecordInvalid.new(request)
    end
  end

  def handle_approval!
    request.approve!(landlord_user)
  end

  def handle_rejection!
    if rejection_reason.blank?
      request.errors.add(:rejection_reason, I18n.t("request.rejection_reason_required", default: "Vui lòng nhập lý do từ chối!"))
      raise ActiveRecord::RecordInvalid.new(request)
    end

    request.reject!(landlord_user, rejection_reason)
  end

  def send_notification
    tenant_user = request.tenant&.user
    return unless tenant_user

    extra_details = request.requestable.respond_to?(:notification_details) ? request.requestable.notification_details : {}

    RequestResolvedNotifier.with(
      {
        request: request,
        decision: decision,
        house_name: request.house&.name,
        reason: rejection_reason
      }.merge(extra_details)
    ).deliver_later(tenant_user)
  end
end
