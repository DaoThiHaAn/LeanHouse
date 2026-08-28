class VehicleRemovedNotifier < ApplicationNotifier
  notification_methods do
    def title
      if recipient.landlord?
        t("noti.titles.vehicle_removed_landlord", default: "Phương tiện đã được xóa khỏi nhà")
      else
        t("noti.titles.vehicle_removed_tenant", default: "Phương tiện đã được xóa khỏi nhà")
      end
    end

    def message
      if recipient.landlord?
        t("noti.messages.vehicle_removed_landlord",
          tenant_name: params[:tenant_name],
          house_name: params[:house_name],
          license_plate: params[:license_plate],
          reason: params[:reason],
          default: "Phương tiện #{params[:license_plate]} của khách #{params[:tenant_name]} đã được xóa khỏi #{params[:house_name]}. Lý do: #{params[:reason]}")
      else
        t("noti.messages.vehicle_removed_tenant",
          house_name: params[:house_name],
          license_plate: params[:license_plate],
          reason: params[:reason],
          default: "Phương tiện #{params[:license_plate]} của bạn tại #{params[:house_name]} đã được xóa. Lý do: #{params[:reason]}")
      end
    end

    def url
      if recipient.landlord?
        landlord_house_vehicles_path(params[:house_id])
      else
        tenant_vehicles_path
      end
    end
  end
end
