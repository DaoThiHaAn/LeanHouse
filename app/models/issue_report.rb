class IssueReport < ApplicationRecord
  belongs_to :resolved_by, class_name: "Admin", optional: true

  enum :status, {
    pending: "pending",
    in_progress: "in_progress",
    resolved: "resolved"
  }

  before_validation :normalize
  validates :email, presence: true,
                    length: { maximum: 255 },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :title, presence: true, length: { minimum: 1, maximum: 100 }
  validates :description, presence: true, length: { minimum: 10, maximum: 5000 }
  validates :status, presence: true, inclusion: { in: statuses.keys }

  after_create_commit :broadcast_pending_badge_later
  after_update_commit :broadcast_pending_badge_later, if: :saved_change_to_status?
  after_destroy_commit :broadcast_pending_badge_later

  scope :recent, -> { order(created_at: :desc) }
  scope :filter_by_status, ->(status) { where(status: status) if status.present? && statuses.key?(status) }
  scope :search, ->(query) {
    return all if query.blank?
    term = "%#{sanitize_sql_like(query.to_s.strip)}%"
    where("email ILIKE :q OR title ILIKE :q", q: term)
  }

  def self.broadcast_pending_badge
    count = where(status: :pending).count
    Turbo::StreamsChannel.broadcast_replace_to(
      :admin_issue_reports,
      target: "admin_issue_reports_nav_badge",
      partial: "admin_portal/issue_reports/nav_badge",
      locals: { count: count }
    )
  end

  def mark_resolved!(admin:, notes: nil)
    update!(
      status: :resolved,
      resolved_by: admin,
      resolved_at: Time.current,
      admin_notes: notes.presence || admin_notes
    )
  end

  def mark_in_progress!(notes: nil)
    update!(
      status: :in_progress,
      admin_notes: notes.presence || admin_notes
    )
  end

  private

  def broadcast_pending_badge_later
    self.class.broadcast_pending_badge
  end

  def normalize
    self.email = email.to_s.squish
    self.title = title.to_s.squish
    self.description = description.to_s.squish
  end
end
