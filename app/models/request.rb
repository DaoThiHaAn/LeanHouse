class Request < ApplicationRecord
  belongs_to :tenant, inverse_of: :requests
  belongs_to :house
  belongs_to :requestable, polymorphic: true, dependent: :destroy
  belongs_to :resolved_by, class_name: "User", optional: true

  enum :status, {
    pending: "pending",
    approved: "approved",
    rejected: "rejected",
    overdue: "overdue"
  }, default: :pending

  EXPIRED_DAYS = 7

  # Require rejection reason only when rejected
  validates :rejection_reason, presence: true, if: :rejected?

  validate :status_can_only_transition_from_pending, on: :update

  scope :pending, -> { where(status: :pending) }
  scope :recent, -> { order(created_at: :desc) }
  scope :expired, -> { pending.where("requests.created_at <= ?", EXPIRED_DAYS.days.ago) }

  REQUEST_TYPES = {
    "VehicleRequest" => "request.vehicle_register",
    "RepairRequest" => "request.repair_request",
    "LeaveHouseRequest" => "request.leave_house"
  }.freeze

  # METHODS

  def human_status
    I18n.t("enums.request.status.#{status}")
  end

  def human_request_type
    key = REQUEST_TYPES[requestable_type]
    if key
      I18n.t(key, default: requestable_type.humanize)
    else
      requestable_type.to_s.underscore.humanize
    end
  end

  # Get the list of status options in i18n format
  def self.status_options
    statuses.keys.map do |status_key|
      [ I18n.t("enums.request.status.#{status_key}", default: status_key.humanize), status_key ]
    end
  end

  # Get the list of request type options in i18n format
  def self.request_type_options
    REQUEST_TYPES.map do |type_class, i18n_key|
      [ I18n.t(i18n_key, default: type_class.humanize), type_class ]
    end
  end

  # Class method to batch expire pending requests older than EXPIRED_DAYS
  def self.expire_overdue!
    expired.find_each(&:mark_as_overdue!)
  end

  def actionable?
    pending? && created_at > EXPIRED_DAYS.days.ago
  end

  def mark_as_overdue!
    return unless pending?

    transaction do
      update!(status: :overdue)
      requestable.try(:purge_documents!)
    end
  end

  # Generic approve method for any request type
  def approve!(landlord_user)
    raise "Request is no longer actionable" unless actionable?

    transaction do
      if requestable.respond_to?(:approve!)
        requestable.approve!(landlord_user)
      else
        update!(
          status: :approved,
          resolved_by: landlord_user,
          resolved_at: Time.current
        )
        requestable.try(:purge_documents!)
      end
    end
  end

  # Generic reject method for any request type
  def reject!(landlord_user, reason)
    raise "Request is no longer actionable" unless actionable?

    transaction do
      if requestable.respond_to?(:reject!)
        requestable.reject!(landlord_user, reason)
      else
        update!(
          status: :rejected,
          rejection_reason: reason,
          resolved_by: landlord_user,
          resolved_at: Time.current
        )
        requestable.try(:purge_documents!)
      end
    end
  end

  private

  def status_can_only_transition_from_pending
    if status_changed? && status_was != "pending"
      errors.add(:status, "đã được xử lý (#{status_was}) và không thể thay đổi trạng thái nữa.")
    end
  end
end
