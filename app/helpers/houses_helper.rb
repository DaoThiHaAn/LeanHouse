module HousesHelper
  def get_rental_mode_val(type)
    case type
    when "room"
      0
    when "bed"
      1
    end
  end
end
