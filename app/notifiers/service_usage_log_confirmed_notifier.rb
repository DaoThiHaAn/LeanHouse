# Notifier dispatched to active staying tenants of a room when a landlord confirms
# and finalizes their meter reading for a billing cycle.
class ServiceUsageLogConfirmedNotifier < ApplicationNotifier
  required_param :log

  notification_methods do
    def title
      t("noti.titles.service_usage_log_confirmed", default: "Chỉ số dịch vụ đã được xác nhận")
    end

    def message
      t("noti.messages.service_usage_log_confirmed",
        service_name: params[:log].service_name,
        month: params[:log].billing_month.strftime("%m/%Y"),
        room_name: params[:log].room.title_name,
        default: "Chủ nhà đã xác nhận chỉ số #{params[:log].service_name} tháng #{params[:log].billing_month.strftime('%m/%Y')} của phòng #{params[:log].room.title_name}."
      )
    end

    def url
      tenant_service_usage_logs_path(month: params[:log].billing_month.strftime("%Y-%m"))
    end
  end
end
