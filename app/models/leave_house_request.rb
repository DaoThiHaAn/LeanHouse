class LeaveHouseRequest < ApplicationRecord
  has_one :request, as: :requestable, dependent: :destroy, inverse_of: :requestable

  # Called when landlord approves the leave house request
  def approve!(landlord_user)
    raise "Request is no longer actionable" unless request.actionable?

    ActiveRecord::Base.transaction do
      # 1. Checkout tenant from house and end active contract if any
      tenant_stay = request.house.tenant_stay_for(request.tenant_id)
      if tenant_stay.present?
        Checkout.call(
          house: request.house,
          tenant_stay: tenant_stay,
          end_contract: true,
          send_noti: false # RequestResolvedNotifier is sent by RequestHandling
        )
      end

      # 2. Update Request status
      request.update!(
        status: :approved,
        resolved_by: landlord_user,
        resolved_at: Time.current
      )
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
    end
  end
end
