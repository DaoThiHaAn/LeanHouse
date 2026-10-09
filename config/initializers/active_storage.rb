# frozen_string_literal: true

Rails.application.config.after_initialize do
  Rails.application.config.active_storage.analyzers.insert(0, ExifImageAnalyzer)
end

ActiveSupport.on_load(:active_storage_blob) do
  include ActiveStorageBlobExif unless include?(ActiveStorageBlobExif)
end
