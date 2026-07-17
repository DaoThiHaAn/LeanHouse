module HousesHelper
  def house_address(house)
    [ house&.address_l3, house&.address_l2, house&.address_l1 ].compact_blank.join(", ")
  end

  def house_mode(house)
    return "(#{t("form.house.room-based")})" if house&.room?
    "(#{t("form.house.bed-based")})" if house&.bed?
  end

  def occupied_rate_format(house)
    "#{house&.occupied_slots} / #{house&.total_slots}"
  end
end
