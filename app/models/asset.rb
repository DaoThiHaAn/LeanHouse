class Asset < ApplicationRecord
  belongs_to :room, inverse_of: :assets
  has_one :house, through: :room, inverse_of: :assets


  BUILT_IN_CATEGORIES = %w[
    fridge
    air_con
    camera
    elec_stove
    wash_mach
    dryer
    smart_door
    water_heater
    tv
  ].freeze

  before_validation :normalize_strings

  validates :price, presence: true,
            numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 1_000_000_000 }
  validates :category, presence: true

  scope :sorted, -> { order(type: :asc) }

  private

  def normalize_strings
    self.brand = brand&.squish
    self.model = model&.squish
    self.note = note&.squish
  end

  # Get the list of category options in i18n format
  def self.category_options
    BUILT_IN_CATEGORIES.map do |cat|
      [ I18n.t("enums.asset.categories.#{cat}", default: cat.humanize), cat ]
    end + [ [ I18n.t("other"), "other" ] ]
  end
  # Hiển thị tên danh mục đã dịch khi xem chi tiết/danh sách
  def human_category
    I18n.t("enums.asset.categories.#{category}", default: category)
  end
end
