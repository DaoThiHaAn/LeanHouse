# frozen_string_literal: true

module ActiveStorageBlobExif
  extend ActiveSupport::Concern

  def captured_at
    return unless image?

    if metadata.key?("captured_at")
      return Time.zone.parse(metadata["captured_at"]) if metadata["captured_at"].present?
      return nil
    end

    extract_and_cache_captured_at
  end

  def extract_and_cache_captured_at
    return unless image?

    extracted_time = nil
    open do |tempfile|
      image = MiniMagick::Image.new(tempfile.path)
      exif = image.exif || {}
      date_str = exif["DateTimeOriginal"].presence || exif["CreateDate"].presence || exif["DateTime"].presence
      if date_str.present?
        iso_str = if date_str.match?(/\A\d{4}:\d{2}:\d{2} \d{2}:\d{2}:\d{2}/)
          Time.zone.strptime(date_str[0..18], "%Y:%m:%d %H:%M:%S").iso8601
        else
          Time.zone.parse(date_str)&.iso8601
        end

        if iso_str
          metadata["captured_at"] = iso_str
          extracted_time = Time.zone.parse(iso_str)
        end
      end
    end

    metadata["captured_at"] ||= nil
    save if persisted?
    extracted_time
  rescue StandardError => e
    Rails.logger.warn "Failed to extract EXIF on-demand: #{e.message}"
    metadata["captured_at"] = nil
    save if persisted?
    nil
  end
end

ActiveStorage::Blob.include(ActiveStorageBlobExif) unless ActiveStorage::Blob.include?(ActiveStorageBlobExif)
