class ApplicationNotifier < Noticed::Event
  # Gửi live update tức thì qua Turbo Stream
  deliver_by :turbo_stream, class: "DeliveryMethods::TurboStream"
end
