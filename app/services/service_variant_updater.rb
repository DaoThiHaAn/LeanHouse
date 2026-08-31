class ServiceVariantUpdater
  def self.update_meta(service_variant, params, notify: false)
    new(service_variant).update_meta(params, notify: notify)
  end

  def self.update_application(service_variant, room_ids, notify: false)
    new(service_variant).update_application(room_ids, notify: notify)
  end

  def initialize(service_variant)
    @service_variant = service_variant
    @service = service_variant.service
    @house = @service.house
  end

  def update_meta(params, notify: false)
    old_fee = @service_variant.fee
    old_unit = @service_variant.human_unit

    if @service_variant.update(params)
      if notify && @service_variant.rooms.any?
        recipients = @service_variant.active_staying_tenant_users
        if recipients.any?
          message_text = I18n.t(
            "noti.messages.service_price_changed",
            service_name: @service.name,
            house_name: @house.name,
            old_fee: ApplicationController.helpers.number_with_delimiter(old_fee),
            new_fee: ApplicationController.helpers.number_with_delimiter(@service_variant.fee),
            unit: @service_variant.human_unit,
            default: "Dịch vụ %{service_name} tại nhà %{house_name} đã cập nhật: %{new_fee}đ/%{unit}."
          )

          ServiceUpdatedNotifier.with(
            service_name: @service.name,
            message_text: message_text
          ).deliver_later(recipients)
        end
      end
      true
    else
      false
    end
  end

  def update_application(room_ids, notify: false)
    affected_room_ids = @service_variant.sync_room_assignments(room_ids)

    if notify && affected_room_ids.any?
      recipients = @service_variant.active_staying_tenant_users(affected_room_ids)
      if recipients.any?
        message_text = I18n.t(
          "noti.messages.service_application_changed",
          service_name: @service.name,
          house_name: @house.name,
          default: "Danh sách phòng áp dụng dịch vụ %{service_name} tại %{house_name} vừa được cập nhật."
        )

        ServiceUpdatedNotifier.with(
          service_name: @service.name,
          message_text: message_text
        ).deliver_later(recipients)
      end
    end

    true
  end
end
