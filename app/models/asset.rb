class Asset < ApplicationRecord
  belongs_to :room, inverse_of: :assets
  has_one :house, through: :room


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
    microwave
  ].freeze

  before_validation :normalize_strings

  validates :price, presence: true,
            numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 1_000_000_000 }
  validates :category, presence: true

  scope :sorted, -> { order(category: :asc) }

  # METHODS
  # Get the list of category options in i18n format
  def self.category_options
    BUILT_IN_CATEGORIES.map do |cat|
      [ I18n.t("enums.asset.categories.#{cat}", default: cat.humanize), cat ]
    end + [ [ I18n.t("other"), "other" ] ]
  end

  # I18n translation for the category options
  def human_category
    I18n.t("enums.asset.categories.#{category}", default: category)
  end

  def location
    room.title_name + ", " + room.floor.title_name
  end

  private

  def normalize_strings
    self.brand = brand&.squish
    self.model = model&.squish
    self.note = note&.squish
  end
end
