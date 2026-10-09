# frozen_string_literal: true

require "test_helper"

class ActiveStorageBlobExifTest < ActiveSupport::TestCase
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

  test "blob responds to captured_at and extracts on-demand when metadata is empty" do
    file = create_jpeg_with_exif("2026:09:20 08:15:30")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: File.open(file.path),
      filename: "test_with_exif.jpg",
      content_type: "image/jpeg"
    )

    captured = blob.captured_at
    assert_not_nil captured
    assert_equal 2026, captured.year
    assert_equal 9, captured.month
    assert_equal 20, captured.day
    assert_equal 8, captured.hour
    assert_equal 15, captured.min
    assert_equal 30, captured.sec

    # Verified cached into metadata
    assert_equal "2026-09-20T08:15:30+07:00", blob.reload.metadata["captured_at"]
  end

  test "blob returns nil and caches nil when image has no EXIF" do
    file = create_jpeg_without_exif
    blob = ActiveStorage::Blob.create_and_upload!(
      io: File.open(file.path),
      filename: "test_without_exif.jpg",
      content_type: "image/jpeg"
    )

    assert_nil blob.captured_at
    assert blob.reload.metadata.key?("captured_at")
  end

  test "blob returns nil for non-image files" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("PDF content"),
      filename: "test.pdf",
      content_type: "application/pdf"
    )

    assert_nil blob.captured_at
  end
end

