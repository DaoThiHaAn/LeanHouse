# frozen_string_literal: true

class ExifImageAnalyzer < ActiveStorage::Analyzer::ImageAnalyzer::ImageMagick
  def metadata
    read_image do |image|
      base_meta = if rotated_image?(image)
        { width: image.height, height: image.width }
      else
        { width: image.width, height: image.height }
      end

      captured_at = extract_captured_at(image)
      base_meta[:captured_at] = captured_at if captured_at
      base_meta
    end
  end

  private

  def extract_captured_at(image)
    exif = image.exif || {}
    date_str = exif["DateTimeOriginal"].presence || exif["CreateDate"].presence || exif["DateTime"].presence
    return if date_str.blank?

    parse_date(date_str)
  rescue StandardError => e
    logger.warn "Failed to extract EXIF captured_at: #{e.message}"
    nil
  end

  def parse_date(date_str)
    if date_str.match?(/\A\d{4}:\d{2}:\d{2} \d{2}:\d{2}:\d{2}/)
      Time.zone.strptime(date_str[0..18], "%Y:%m:%d %H:%M:%S").iso8601
    else
      Time.zone.parse(date_str)&.iso8601
    end
  rescue StandardError
    nil
  end
end
