class ServiceUnit < ApplicationRecord
  has_many :service_unit_translations, dependent: :destroy

  def translated_name
    service_unit_translations.find_by(locale: I18n.locale.to_s)&.name ||
      service_unit_translations.find_by(locale: I18n.default_locale.to_s)&.name
  end
end
