puts "🌱 Seeding service units..."

units = [
  {
    code: "hour",
    translations: {
      en: "Hour",
      vi: "Giờ"
    }
  },
  {
    code: "day",
    translations: {
      en: "Day",
      vi: "Ngày"
    }
  },
  {
    code: "month",
    translations: {
      en: "Month",
      vi: "Tháng"
    }
  },
  {
    code: "kWh",
    translations: {
      en: "kWh",
      vi: "kWh"
    }
  },
  {
    code: "m3",
    translations: {
      en: "m³",
      vi: "m³"
    }
  },
  {
    code: "person",
    translations: {
      en: "Person",
      vi: "Người"
    }
  },
  {
    code: "item",
    translations: {
      en: "Item",
      vi: "Cái"
    }
  },
  {
    code: "time",
    translations: {
      en: "Time",
      vi: "Lần"
    }
  }
]

units.each do |unit_data|
  service_unit = ServiceUnit.find_or_create_by!(code: unit_data[:code])

  unit_data[:translations].each do |locale, name|
    ServiceUnitTranslation.find_or_create_by!(
      service_unit_id: service_unit.id,
      locale: locale
    ) do |t|
      t.name = name
    end
  end
end

puts "✅ Service units seeded"
