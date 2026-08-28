class RequestResolvedNotifier < ApplicationNotifier
  required_param :request

  notification_methods do
    def title
      req = params[:request]
      type_key = req.requestable_type.underscore
      decision = params[:decision]

      # Looks for specific title e.g. noti.titles.vehicle_request_approved
      # Falls back to generic title: noti.titles.request_approved
      I18n.t(
        "noti.titles.#{type_key}_#{decision}",
        default: I18n.t("noti.titles.request_#{decision}", default: "Yêu cầu đã được xử lý")
      )
    end

    def message
      req = params[:request]
      type_key = req.requestable_type.underscore
      decision = params[:decision]

      # Dynamic convention lookup:
      # 1. noti.messages.<type_key>_<decision>_tenant (e.g. noti.messages.vehicle_request_approved_tenant)
      # 2. Falls back to noti.messages.request_<decision>_tenant
      I18n.t(
        "noti.messages.#{type_key}_#{decision}_tenant",
        **params.symbolize_keys.merge(request_type: req.human_request_type),
          default: begin
            decision_text = case decision
            when "approved" then "duyệt"
            when "handling" then "tiếp nhận xử lý"
            when "completed" then "hoàn thành"
            when "rejected" then "từ chối"
            else "cập nhật trạng thái"
            end
            "Chủ nhà đã #{decision_text} #{req.human_request_type} tại #{params[:house_name]}."
          end
      )
    end

    def url
      tenant_requests_path
    end
  end
end
