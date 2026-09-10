class CustomAnnouncementNotifier < ApplicationNotifier
  required_param :title
  required_param :message

  notification_methods do
    def title
      params[:title]
    end

    def message
      params[:message]
    end

    def url
      params[:url].presence
    end

    def level
      params[:level].presence || "info"
    end

    def sender_name
      params[:sender_name].presence || "LeanHouse Admin"
    end
  end
end
