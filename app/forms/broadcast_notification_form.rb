class BroadcastNotificationForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :target_audience, :string, default: "all"
  attribute :title, :string
  attribute :message, :string
  attribute :url, :string
  attribute :level, :string, default: "info"

  AUDIENCES = %w[all landlords tenants].freeze
  LEVELS = %w[info warning urgent].freeze

  validates :title, presence: true, length: { maximum: 150 }
  validates :message, presence: true
  validates :target_audience, inclusion: { in: AUDIENCES }
  validates :level, inclusion: { in: LEVELS }

  def title=(val)
    super(val&.to_s&.squish)
  end

  def message=(val)
    super(val&.to_s&.squish)
  end

  def url=(val)
    super(val&.to_s&.squish.presence)
  end

  def target_audience=(val)
    cleaned = val&.to_s&.squish
    super(cleaned.presence_in(AUDIENCES) || "all")
  end

  def level=(val)
    cleaned = val&.to_s&.squish
    super(cleaned.presence_in(LEVELS) || "info")
  end

  def audience_scope
    case target_audience
    when "landlords"
      User.active.where(role: :landlord)
    when "tenants"
      User.active.where(role: :tenant)
    else
      User.active.where.not(role: :admin)
    end
  end

  def recipient_count
    audience_scope.count
  end
end

BroadcastNotification = BroadcastNotificationForm
