module LocationsHelper
  def province_name(code)
    return nil if code.blank?

    provinces = load_locations["province"]
    provinces.find { |p| p["idProvince"] == code }&.dig("name")
  end

  def commune_name(code)
    return nil if code.blank?

    communes = load_locations["commune"]
    communes.find { |c| c["idCommune"] == code }&.dig("name")
  end

  private

  def load_locations
    @load_locations ||= JSON.parse(
      File.read(Rails.root.join("data/vn_locations.json"))
    )
  end
end
