# frozen_string_literal: true

require "test_helper"

class ExifImageAnalyzerTest < ActiveSupport::TestCase
  def create_jpeg_with_exif(date_string)
    tmp = Tempfile.new(["blank", ".jpg"])
    system("convert", "-size", "10x10", "xc:white", tmp.path)
    jpg_bytes = File.binread(tmp.path)

    tiff_header = "II" + [42, 8].pack("vV")
    tag_id = 0x0132 # DateTime
    tag_type = 2
    tag_count = 20
    val_offset = 8 + 2 + 12 + 4 # 26
    ifd0 = [1].pack("v") + [tag_id, tag_type, tag_count, val_offset].pack("vvVV") + [0].pack("V")
    date_payload = date_string.ljust(19, " ") + "\0"
    tiff_data = tiff_header + ifd0 + date_payload
    app1_payload = "Exif\0\0" + tiff_data
    app1_segment = [0xFF, 0xE1, app1_payload.bytesize + 2].pack("CCn") + app1_payload
    new_jpg = jpg_bytes[0..1] + app1_segment + jpg_bytes[2..-1]

    file = Tempfile.new(["exif_img", ".jpg"])
    File.binwrite(file.path, new_jpg)
    file
  end

  def create_jpeg_without_exif
    file = Tempfile.new(["plain_img", ".jpg"])
    system("convert", "-size", "10x10", "xc:white", file.path)
    file
  end

  test "extracts captured_at when EXIF date is present" do
    file = create_jpeg_with_exif("2026:08:15 14:30:45")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: File.open(file.path),
      filename: "with_exif.jpg",
      content_type: "image/jpeg"
    )

    metadata = ExifImageAnalyzer.new(blob).metadata
    assert_equal 10, metadata[:width]
    assert_equal 10, metadata[:height]
    assert_equal "2026-08-15T14:30:45+07:00", metadata[:captured_at]
  end

  test "extracts width and height without captured_at when EXIF date is absent" do
    file = create_jpeg_without_exif
    blob = ActiveStorage::Blob.create_and_upload!(
      io: File.open(file.path),
      filename: "without_exif.jpg",
      content_type: "image/jpeg"
    )

    metadata = ExifImageAnalyzer.new(blob).metadata
    assert_equal 10, metadata[:width]
    assert_equal 10, metadata[:height]
    assert_nil metadata[:captured_at]
  end
end

