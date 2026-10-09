# frozen_string_literal: true

Rails.application.config.after_initialize do
  Rails.application.config.active_storage.analyzers.insert(0, ExifImageAnalyzer)
end

Rails.application.config.to_prepare do
  ActiveStorage::Blob.include(ActiveStorageBlobExif) unless ActiveStorage::Blob.include?(ActiveStorageBlobExif)
end
