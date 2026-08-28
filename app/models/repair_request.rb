class RepairRequest < ApplicationRecord
  has_one :request, as: :requestable, dependent: :destroy, inverse_of: :requestable

  has_many_attached :images
  has_one_attached :video

  MAX_IMAGES = 5
  MAX_IMAGE_SIZE = 10.megabytes
  MAX_VIDEO_SIZE = 50.megabytes
  ALLOWED_IMAGE_TYPES = %w[image/jpeg image/jpg image/png image/webp image/heic].freeze
  ALLOWED_VIDEO_TYPES = %w[video/mp4 video/quicktime video/webm video/x-msvideo video/mpeg].freeze

  before_validation :normalize_attributes

  validates :title, presence: true, length: { maximum: 100 }
  validates :content, presence: true, length: { maximum: 500 }
  validate :validate_attachments

  def notification_details
    {
      title: title
    }
  end

  # Called when landlord starts handling
  def start_handling!(landlord_user)
    raise "Request is no longer actionable" unless request.actionable?

    ActiveRecord::Base.transaction do
      request.update!(
        status: :handling,
        resolved_by: landlord_user,
        resolved_at: Time.current
      )
    end
  end

  # Called when landlord completes repair
  def complete!(landlord_user)
    raise "Request is no longer actionable" unless request.actionable?

    ActiveRecord::Base.transaction do
      request.update!(
        status: :completed,
        resolved_by: landlord_user,
        resolved_at: Time.current
      )
    end
  end

  # Called when landlord rejects
  def reject!(landlord_user, reason = nil)
    raise "Request is no longer actionable" unless request.actionable?

    ActiveRecord::Base.transaction do
      request.update!(
        status: :rejected,
        rejection_reason: reason,
        resolved_by: landlord_user,
        resolved_at: Time.current
      )
    end
  end

  private

  def normalize_attributes
    self.title = title&.squish
    self.content = content&.strip
  end

  def validate_attachments
    validate_images
    validate_video
  end

  def validate_images
    return unless images.attached?

    if images.length > MAX_IMAGES
      errors.add(:images, :too_long, count: MAX_IMAGES)
    end

    images.each do |img|
      if img.blob.byte_size > MAX_IMAGE_SIZE
        errors.add(:images, :file_too_big, size: "10MB")
      end

      unless ALLOWED_IMAGE_TYPES.include?(img.blob.content_type)
        errors.add(:images, :invalid_content_type)
      end
    end
  end

  def validate_video
    return unless video.attached?

    if video.blob.byte_size > MAX_VIDEO_SIZE
      errors.add(:video, :file_too_big, size: "50MB")
    end

    unless ALLOWED_VIDEO_TYPES.include?(video.blob.content_type)
      errors.add(:video, :invalid_content_type)
    end
  end
end
