class VehicleRequestCreatedNotifier < ApplicationNotifier
  required_param :request

  notification_methods do
    def title
      if recipient.landlord?
        t("noti.titles.request_created_landlord")
      else
        t("noti.titles.request_created_tenant")
      end
    end

    def message
      if recipient.landlord?
        t("noti.messages.vehicle_request_created_landlord",
          tenant_name: params[:tenant_name],
          house_name: params[:house_name],
          location: params[:location],
          license_plate: params[:license_plate])
      else
        t("noti.messages.vehicle_request_created_tenant",
          house_name: params[:house_name],
          license_plate: params[:license_plate])
      end
    end

    def url
      if recipient.landlord?
        landlord_requests_path
      else
        tenant_requests_path
      end
    end
  end
end
