module HousesHelper
  def house_address(house)
    [ house&.address_l3, house&.address_l2, house&.address_l1 ].compact_blank.join(", ")
  end

  def house_mode(house)
    return "(#{t("form.house.room-based")})" if house&.room?
    "(#{t("form.house.bed-based")})"
  end

  def house_mode_icon(house)
    return "living" if house&.room?
    "bed"
  end

  def occupied_rate_format(house)
    "#{house&.occupied_slots} / #{house&.total_slots}"
  end

  # Configuration hash mapping modes to their asset & translation keys
  HOUSE_MODE_CONFIG = {
    "room" => {
      image: "room-based.png",
      title_key: "form.house.room",
      info_key: "form.house.room-based"
    },
    "bed" => {
      image: "bed-based.png", # Adjust image names to match your assets
      title_key: "form.house.bed",
      info_key: "form.house.bed-based"
    }
    # Add other modes here as needed
  }.freeze

  def house_mode_badge(house, options = {})
    # Fallback to room config if mode isn't found
    config = HOUSE_MODE_CONFIG.fetch(house.mode.to_s, HOUSE_MODE_CONFIG["room"])

    content_tag :div,
                class: "pe-none m-auto view role-option d-flex flex-column align-items-center gap-1 px-2 py-1".strip do
      concat image_tag(config[:image], alt: t(config[:title_key]))
      concat content_tag(:p, t(config[:title_key]))
      concat content_tag(:p, "(#{t(config[:info_key])})", class: "mode-info")
    end
  end

  # Show general detail of Floor
  def floor_general_details(floor)
    "#{floor.title_name} " +
    "- #{floor.rooms_count} #{t('form.room.self')} " +
    "(#{t("form.floor.total_slots")}: #{floor.total_slots})"
  end
end
