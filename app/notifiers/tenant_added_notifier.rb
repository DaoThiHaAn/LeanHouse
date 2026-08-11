# To deliver this notification:
#
# TenantAddedNotifier.with(record: @post, message: "New post").deliver(User.all)

class TenantAddedNotifier < ApplicationNotifier
  # Add your delivery methods
  #
  # deliver_by :email do |config|
  #   config.mailer = "UserMailer"
  #   config.method = "new_post"
  # end
  #
  # bulk_deliver_by :slack do |config|
  #   config.url = -> { Rails.application.credentials.slack_webhook_url }
  # end
  #
  # deliver_by :custom do |config|
  #   config.class = "MyDeliveryMethod"
  # end

  # Add required params
  #
  # required_param :message

  # Compute recipients without having to pass them in
  #
  # recipients do
  #   params[:record].thread.all_authors
  # end

  required_param :tenant_stay

  notification_methods do
    def title
      "You have been added to a rental"
    end

    def message
      t("noti.tenant_added",
        house: params[:house],
        floor: params[:floor],
        rental_unit:  params[:rental_unit])
    end

    def url
      tenant_stay_path(params[:tenant_stay])
    end

    private

    def rental_unit_name
      params[:tenant_stay].rental_unit.name
    end
  end
end
