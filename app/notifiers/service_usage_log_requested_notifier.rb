# frozen_string_literal: true

# Notifier dispatched to active staying tenants of a room when a landlord creates
# an unconfirmed meter reading entry and requests the tenant to photograph and submit readings.
class ServiceUsageLogRequestedNotifier < ApplicationNotifier
  required_param :log

  notification_methods do
    def title
      t("noti.titles.service_usage_log_requested", default: "Yêu cầu nộp chỉ số dịch vụ")
    end

    def message
      t("noti.messages.service_usage_log_requested",
        service_name: params[:log].service_name,
        month: params[:log].billing_month.strftime("%m/%Y"),
        room_name: params[:log].room.title_name,
        default: "Chủ nhà đã mở đợt ghi chỉ số #{params[:log].service_name} tháng #{params[:log].billing_month.strftime('%m/%Y')} của phòng #{params[:log].room.title_name}. Vui lòng chụp ảnh công tơ và nộp chỉ số."
      )
    end

    def url
      tenant_service_usage_logs_path(month: params[:log].billing_month.strftime("%Y-%m"))
    end
  end
end
